# frozen_string_literal: true
require 'telegram/bot'
require 'CoolRubyGem'
require 'CoolRubyGem/rule'
require 'CoolRubyGem/system'

token = '8785997708:AAFzO-M6h4Qp7gq8RDPKEdlGNo4JsmG23pk'

class UserSession
  attr_accessor :mode, :data
  def initialize
    @mode = nil          # :waiting_for_rule, :waiting_for_word, nil
    @data = {}           # { rules: [], word: nil, ... }
  end
end


class MarkovBot
  def initialize(token)
    @token = token
    @sessions = {}       # chat_id -> UserSession
  end

  def start
    Telegram::Bot::Client.run(@token) do |bot|
      @bot = bot
      puts "Бот запущен"
      bot.listen { |message| handle_message(message) }
    end
  end

  private

  def handle_message(message)
    chat_id = message.chat.id
    text = message.text.to_s

    # Инициализируем сессию, если её нет
    @sessions[chat_id] ||= UserSession.new
    session = @sessions[chat_id]

    # Обработка команд /start, /stop, /help (разрешён ручной ввод)
    if text == '/start'
      puts "#{chat_id}- /start"
      start_command(chat_id)
      return
    elsif text == '/stop'
      puts "#{chat_id}- /stop"
      stop_command(chat_id)
      return
    elsif text == '/help'
      puts  "#{chat_id}- /help"
      help_command(chat_id)
      return
    end

    # Если пользователь в режиме ожидания ввода – обрабатываем как данные
    if session.mode == :waiting_for_rule
      process_rule_input(chat_id, text)
    elsif session.mode == :waiting_for_word
      process_word_input(chat_id, text)
    else
      # Не в режиме ввода – проверяем, не нажата ли кнопка (действие)
      case text
      when '📝 Ввести систему'
        puts "#{chat_id}- Ввести систему"
        start_system_input(chat_id)
      when '🔤 Ввести слово'
        puts "#{chat_id}- Ввести слово"
        start_word_input(chat_id)
      when '❌ Завершить ввод'
        puts "#{chat_id}- Завершить ввод"
        cancel_input(chat_id)
      when '🏠 Главное меню'
        puts "#{chat_id}- Главное меню"
        show_main_menu(chat_id)
      else
        puts "#{chat_id}- текст не распознан как действие "
        # Если текст не распознан как действие – игнорируем или показываем меню
        @bot.api.send_message(

          chat_id: chat_id,
          text: "Пожалуйста, используйте кнопки. Если вы вводите правило или слово, сначала нажмите соответствующую кнопку.",
          reply_markup: main_menu_keyboard
        )
      end
    end
  end

  # ---- Команды ----
  def start_command(chat_id)
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Привет! Я бот для алгоритмов Маркова.\nИспользуйте кнопки ниже.",
      reply_markup: main_menu_keyboard
    )
  end

  def stop_command(chat_id)
    @bot.api.send_message(
      chat_id: chat_id,
      text: "До свидания! Чтобы начать заново, нажмите /start",
      reply_markup: Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    )
    @sessions.delete(chat_id)
  end

  def help_command(chat_id)
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Доступные действия:\n📝 Ввести систему правил\n🔤 Ввести слово\n\nПосле ввода системы и слова я применю алгоритм Маркова.",
      reply_markup: main_menu_keyboard
    )
  end

  # ---- Действия по кнопкам ----
  def show_main_menu(chat_id)
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Главное меню",
      reply_markup: main_menu_keyboard
    )
  end

  def start_system_input(chat_id)
    session = @sessions[chat_id]
    session.mode = :waiting_for_rule
    session.data[:rules] = []

    @bot.api.send_message(
      chat_id: chat_id,
      text: "Введите правило в формате: A->B или A->.B (точка означает завершающее правило).\nКогда закончите, нажмите кнопку '❌ Завершить ввод'.",
      reply_markup: cancel_keyboard   # клавиатура с кнопкой "Завершить ввод"
    )
  end

  def start_word_input(chat_id)
    session = @sessions[chat_id]
    session.mode = :waiting_for_word

    @bot.api.send_message(
      chat_id: chat_id,
      text: "Введите исходное слово (например, abab):",
      reply_markup: cancel_keyboard
    )
  end

  def cancel_input(chat_id)
    puts "#{chat_id}- Ввод завершен "
    session = @sessions[chat_id]
    session.mode = nil
    session.data = {}
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Ввод отменён. Возвращаемся в главное меню.",
      reply_markup: main_menu_keyboard
    )
  end

  # ---- Обработка ввода данных ----
  def process_rule_input(chat_id, rule_text)
    session = @sessions[chat_id]
    puts "#{chat_id}- Обработка ввода правил"
    puts "Defined? #{defined?(CoolRubyGem)}"
    puts "Defined? #{defined?(CoolRubyGem::Rule)}"
    # Здесь можно добавить валидацию формата правила с использованием вашего гема
    if (rule_text == '❌ Завершить ввод')
      cancel_input(chat_id)
    else
      begin
        rule = CoolRubyGem::Rule.new(rule_text)
        session.data[:rules] << rule
        @bot.api.send_message(
          chat_id: chat_id,
          text: "✅ Правило добавлено: #{rule.to_s}\nТекущая система: #{session.data[:rules].map(&:to_s).join(', ')}\nВведите ещё правило или нажмите 'Завершить ввод'."
        )
      rescue => e
        @bot.api.send_message(
          chat_id: chat_id,
          text: "❌ Ошибка: #{e.message}\nПопробуйте снова. Формат: A->B или A->.B"
        )
      end
    end
  end

  def process_word_input(chat_id, word)
    puts "#{chat_id}- Обработка ввода слов"
    session = @sessions[chat_id]
    session.data[:word] = word

    # Если система правил уже введена, можно сразу применить
    if session.data[:rules] && !session.data[:rules].empty?
      apply_algorithm(chat_id)
    else
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Слово '#{word}' сохранено. Теперь введите систему правил (кнопка '📝 Ввести систему').",
        reply_markup: main_menu_keyboard
      )
      session.mode = nil   # выходим из режима ожидания слова
    end
  end

  def apply_algorithm(chat_id)
    puts "#{chat_id}- Результат подстановки"
    session = @sessions[chat_id]
    rules = CoolRubyGem::System.new(session.data[:rules])
    word = session.data[:word]

    # Здесь ваш алгоритм применения правил Маркова
    result = rules.result(word)

    @bot.api.send_message(
      chat_id: chat_id,
      text: "Система: #{rules.map(&:to_s).join(', ')}\nИсходное слово: #{word}\nРезультат: #{result}",
      reply_markup: main_menu_keyboard
    )
    session.mode = nil
    session.data = {}
  end

  # ---- Клавиатуры ----
  def main_menu_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [{ text: '📝 Ввести систему' }, { text: '🔤 Ввести слово' }],
        [{ text: '/help' }, { text: '/stop' }]
      ],
      resize_keyboard: true,
      one_time_keyboard: false
    )
  end

  def cancel_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [{ text: '❌ Завершить ввод' }],
        [{ text: '🏠 Главное меню' }]
      ],
      resize_keyboard: true,
      one_time_keyboard: false
    )
  end
end

# Запуск
MarkovBot.new(token).start