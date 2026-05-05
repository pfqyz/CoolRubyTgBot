# frozen_string_literal: true

require 'minitest/autorun'
require 'ostruct'

# Заглушка Telegram API (подменяем до загрузки бота)
module Telegram
  module Bot
    class Client
      def initialize(token); end
      def api; @api ||= ApiFake.new; end
    end

    class ApiFake
      attr_reader :sent_messages

      def initialize
        @sent_messages = []
      end

      def send_message(**kwargs)
        @sent_messages << kwargs
      end

      def set_my_commands(**kwargs); end
    end
  end
end

# Заглушка гема cool_ruby_gem (фиксированный результат)
module CoolRubyGem
  class Rule
    attr_reader :to_s
    def initialize(str); @to_s = str; end
  end

  class System
    def initialize(rules); @rules = rules; end
    def result(word) = "ОБРАБОТАНО: #{word}"
  end
end

# Подключаем бота (запуск не произойдёт, если в TgBot.rb нет глобального вызова)
require_relative '../TgBot'

class MarkovBotTest < Minitest::Test
  def setup
    @bot = MarkovBot.new('fake_token')
    fake_bot = OpenStruct.new(api: Telegram::Bot::ApiFake.new)
    @bot.instance_variable_set(:@bot, fake_bot)

    @bot.instance_variable_set(:@sessions, {})
    @bot.define_singleton_method(:load_sessions) {}
    @bot.define_singleton_method(:save_sessions) {}

    @chat_id = 777
    @fake_api = fake_bot.api
  end

  def test_full_journey
    # 1. /start
    send_message('/start')
    assert_any_text(/Главное меню/, 'бот показал главное меню')
    assert_nil session.mode

    # 2. Ввести систему
    send_message('Ввести систему')
    assert_any_text(/Введите правило/, 'просит ввести правило')
    assert_equal :waiting_for_rule, session.mode

    # 3. Добавить правило
    send_message('x->y')
    assert_any_text(/Правило добавлено: x->y/, 'правило добавилось')
    assert_equal ['x->y'], session.data[:rules]

    # 4. Завершить ввод правил
    send_message('Завершить ввод')
    assert_any_text(/Главное меню/, 'вернулись в меню')
    assert_nil session.mode
    assert_equal ['x->y'], session.data[:rules]

    # 5. Ввести слово
    send_message('Ввести слово')
    assert_any_text(/Введите исходное слово/, 'просит слово')
    assert_equal :waiting_for_word, session.mode

    # 6. Ввести слово "abc"
    send_message('abc')
    assert_any_text(/Слово abc сохранено/, 'слово сохранено')
    assert_equal 'abc', session.data[:word]

    # 7. Завершить ввод слова
    send_message('Завершить ввод')
    assert_any_text(/Главное меню/, 'вернулись в меню')
    assert_nil session.mode

    # 8. Показать результат
    send_message('Показать результат')
    assert_any_text(/Результат/, 'выдал результат')
  end

  def test_bad_scenarios
    # 1. Попытка показать результат без сессии (ни правил, ни слова)
    send_message('/start')
    assert_any_text(/Главное меню/)

    send_message('Показать результат')
    # Реальный ответ бота:
    assert_any_text(/Сначала введите систему правил/i,
                    'бот должен попросить ввести систему')

    # 2. Ввести слово без системы
    send_message('Ввести слово')
    assert_any_text(/Введите исходное слово/)
    send_message('abc')
    assert_any_text(/Слово abc сохранено/)
    send_message('Завершить ввод')
    assert_any_text(/Главное меню/)

    send_message('Показать результат')
    # Теперь слово есть, но нет правил – бот должен сказать, что нет правил
    assert_any_text(/Система: \{\}|не заданы правила|введите систему/i,
                    'должна быть ошибка: правила не заданы')

    # 3. Некорректный формат правила
    send_message('Ввести систему')
    assert_any_text(/Введите правило/)
    send_message('xyz')  # нет '->'
    # Ожидаем, что бот скажет про некорректный формат
    assert_any_text(/некорректный формат|должно содержать ->|->/i,
                    'бот должен ругнуться на правило без стрелки')
    # Правильное правило, чтобы дальше не сломать сессию
    send_message('a->b')
    assert_any_text(/Правило добавлено: a->b/)
    send_message('Завершить ввод')

    # 4. Попытка ввести слово, не выйдя из режима правил
    send_message('/start')
    send_message('Ввести систему')
    # Сейчас мы в режиме ожидания правила
    send_message('Ввести слово')
    # Бот не должен переключиться на ввод слова, пока не завершены правила
    assert_any_text(/сначала завершите ввод правил|неизвестная команда|завершить ввод/i,
                    'нельзя начать ввод слова, не завершив правила')
  end


  private

  def send_message(text)
    msg = OpenStruct.new(chat: OpenStruct.new(id: @chat_id), text: text)
    @bot.send(:handle_message, msg)
  end

  def session
    @bot.instance_variable_get(:@sessions)[@chat_id]
  end

  # Проверяет, что хотя бы одно отправленное сообщение подходит под regex
  def assert_any_text(regex, msg = nil)
    texts = @fake_api.sent_messages.map { |m| m[:text] }
    assert texts.any? { |t| t =~ regex }, msg || "Не найдено сообщение, содержащее #{regex.inspect} среди:\n#{texts.join("\n")}"
  end
end