# frozen_string_literal: true

require 'telegram/bot'
require 'cool_ruby_gem'
require_relative 'settings'
require 'json'

SESSION_FILE = 'sessions.json'
TEXT_SYSTEM_COMMANDS = "Введите правило в формате: a->b или a->.b (точка означает завершающее правило).\n
Для ввода правила с eps используйте e(англ.)
Когда закончите, нажмите кнопку 'Завершить ввод'.\n
Нажмите 'Главное меню', если не хотите сохранять изменения, вы перейдете в главное меню."

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

    load_sessions
  end

  def start
    Telegram::Bot::Client.run(@token) do |bot|
      @bot = bot
      #bot.api.delete_webhook
      bot.api.set_my_commands(
        commands: [
          { command: '/start', description: 'Начать работу с ботом' },
          { command: '/help', description: 'Получить справку' },
          { command: '/stop', description: 'Закончить работу с ботом' }
        ]
      )
      puts 'Бот запущен'
      bot.listen { |message| handle_message(message) }
    end
  end

  private
  def load_sessions
    return unless File.exist?(SESSION_FILE)
    data = JSON.parse(File.read(SESSION_FILE))
    data.each do |chat_id_str, session_data|
      chat_id = chat_id_str.to_i
      session = UserSession.new
      # Восстанавливаем mode (символ или nil)
      mode_str = session_data['mode']
      session.mode = mode_str ? mode_str.to_sym : nil
      session.data = {
        'rules' => session_data['rules'] || [],
        'word'   => session_data['word']
      }
      @sessions[chat_id] = session
    end
  rescue => e
    puts "Ошибка загрузки сессий: #{e.message}"
  end

  def save_sessions
    data = {}
    @sessions.each do |chat_id, session|
      data[chat_id.to_s] = {
        'mode'  => session.mode ? session.mode.to_s : nil,
        'rules' => session.data[:rules] || [],
        'word'  => session.data[:word]
      }
    end
    File.write(SESSION_FILE, JSON.pretty_generate(data))
  rescue => e
    puts "Ошибка сохранения сессий: #{e.message}"
  end

  def handle_message(message)
    chat_id = message.chat.id
    text = message.text.to_s

    # Инициализируем сессию, если её нет
    @sessions[chat_id] ||= UserSession.new
    session = @sessions[chat_id]

    # Обработка команд /start, /stop, /help (разрешён ручной ввод)
    case text
    when '/start'
      puts "#{chat_id}- /start"
      session.mode = nil
      session.data = {}
      start_command(chat_id)
      show_main_menu(chat_id)
      return
    when '/stop'
      puts "#{chat_id}- /stop"
      stop_command(chat_id)
      return
    when '/help'
      puts "#{chat_id}- /help"
      help_command(chat_id)
      return
    when 'Сбросить всё'
      puts "#{chat_id}- Сбросить всё"
      reset_all(chat_id)
    end

    # Если пользователь в режиме ожидания ввода – обрабатываем как данные
    if session.mode == :waiting_for_rule
      process_rule_input(chat_id, text)
    elsif session.mode == :waiting_for_word
      process_word_input(chat_id, text)
    else
      # Не в режиме ввода – проверяем, не нажата ли кнопка (действие)
      case text
      when 'Ввести систему'
        puts "#{chat_id}- Ввести систему"
        start_system_input(chat_id)
      when 'Ввести слово'
        puts "#{chat_id}- Ввести слово"
        start_word_input(chat_id)
      when 'Ввести другое слово'
        puts "#{chat_id}- Ввести другое слово"
        session.data[:word] = nil
        start_word_input(chat_id)
      when 'Завершить ввод'
        puts "#{chat_id}- Завершить ввод"
        finish_input(chat_id)
      when 'Главное меню'
        puts "#{chat_id}- Главное меню"
        show_main_menu(chat_id)
      when 'Удалить последнее правило'
        puts "#{chat_id}- Удалить последнее правило"
        delete_last_rule(chat_id)
      when 'Показать результат'
        puts "#{chat_id}- Показать результат"
        show_result(chat_id)
      when 'Пошаговое решение'
        puts "#{chat_id}- Пошаговый вывод"
        apply_algorithm_step_by_step(chat_id)
      else
        puts "#{chat_id}- текст не распознан как действие "
        # Если текст не распознан как действие – игнорируем или показываем меню
        @bot.api.send_message(
          chat_id: chat_id,
          text: 'Пожалуйста, используйте кнопки. Если вы вводите правило или слово, сначала нажмите соответствующую кнопку.',
          reply_markup: main_menu_keyboard
        )
      end
    end
  end

  def delete_last_rule(chat_id)
    session = @sessions[chat_id]
    if session.data[:rules].nil? || session.data[:rules].empty?
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Правил пока нет.\n\n#{TEXT_SYSTEM_COMMANDS}",
        reply_markup: system_keyboard
      )
      return
    end
    session.data[:rules].pop
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Последнее правило удалено. Текущая система: {#{session.data[:rules].join(', ')}}\n\n#{TEXT_SYSTEM_COMMANDS}",
      reply_markup: system_keyboard
    )
    save_sessions
  end

  # Очищаем систему правил полностью
  def clear_system(chat_id)
    session = @sessions[chat_id]

    if session.data[:rules].nil? || session.data[:rules].empty?
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Система правил пуста. Введите новые правила.\n\n#{TEXT_SYSTEM_COMMANDS}",
        reply_markup: system_keyboard
      )
      return
    end

    # Очищаем массив правил
    session.data[:rules] = []

    @bot.api.send_message(
      chat_id: chat_id,
      text: "Система очищена. Теперь вы можете ввести новые правила.\n\n#{TEXT_SYSTEM_COMMANDS}",
      reply_markup: system_keyboard
    )
    save_sessions
  end

  def reset_all(chat_id)
    session = @sessions[chat_id]
    session.mode = nil
    session.data = {}
    @bot.api.send_message(
      chat_id: chat_id,
      text: "🧹 Всё сброшено!\n\nПравила и слово удалены. Можете начать заново.",
      reply_markup: main_menu_keyboard
    )
    save_sessions
  end


  # ---- Базовые команды ----
  def start_command(chat_id)
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Привет! Я бот для алгоритмов Маркова.\nИспользуйте кнопки ниже.",
      reply_markup: main_menu_keyboard
    )
    save_sessions
  end

  def stop_command(chat_id)
    @bot.api.send_message(
      chat_id: chat_id,
      text: 'До свидания! Чтобы начать заново, нажмите /start',
      reply_markup: Telegram::Bot::Types::ReplyKeyboardRemove.new(remove_keyboard: true)
    )
    @sessions.delete(chat_id)
    save_sessions
  end

  def help_command(chat_id)
    session = @sessions[chat_id]
    session.mode = nil
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Доступные действия:\n
Ввести систему правил\n
Ввести слово\n
Помощь(/help)\n
Начать работу(/start)\n
Остановить работу(/stop)\n\n
После ввода системы и слова я применю алгоритм Маркова.",
      reply_markup: main_menu_keyboard
    )
  end

  # ---- Действия по кнопкам ----
  def show_result(chat_id)
    session = @sessions[chat_id]
    session.mode = nil
    apply_algorithm(chat_id)
  end

  def apply_algorithm_step_by_step(chat_id)
    session = @sessions[chat_id]
    return unless session.data[:rules]&.any? && session.data[:word]&.size&.positive?

    rules = CoolRubyGem::System.new(session.data[:rules])
    word = session.data[:word].dup

    result = nil
    log = capture_stdout { result = rules.step_by_step_solution(word) }

    if log.empty?
      @bot.api.send_message(chat_id: chat_id, text: "Результат: #{result}")
    else
      messages = log.each_line.chunk_while { |_, after| after.length < 4000 }.map(&:join)
      messages.each { |msg| @bot.api.send_message(chat_id: chat_id, text: "```\n#{msg}\n```", parse_mode: 'Markdown') }
      @bot.api.send_message(chat_id: chat_id, text: "Результат: #{result}")
    end
    show_main_menu(chat_id)
  end

  def capture_stdout
    original = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original
  end


  def show_main_menu(chat_id)
    session = @sessions[chat_id]
    session.mode = nil
    rules = session.data[:rules] || []
    word  = session.data[:word] || 'не введено'
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Главное меню\n\n
Система: {#{rules.join(', ')}}\n
Исходное слово: #{word}",
      reply_markup: main_menu_keyboard
    )
  end

  def start_system_input(chat_id)
    session = @sessions[chat_id]
    session.mode = :waiting_for_rule
    session.data[:rules] ||= []

    @bot.api.send_message(
      chat_id: chat_id,
      text: "#{TEXT_SYSTEM_COMMANDS}",
      reply_markup: system_keyboard
    )
    save_sessions
  end

  def start_word_input(chat_id)
    session = @sessions[chat_id]
    session.mode = :waiting_for_word

    @bot.api.send_message(
      chat_id: chat_id,
      text: 'Введите исходное слово (например, abab):',
      reply_markup: cancel_word_keyboard
    )
    save_sessions
  end

  def finish_input(chat_id)
    puts "#{chat_id}- Ввод завершен "
    session = @sessions[chat_id]
    mode = session.mode

    if mode == :waiting_for_rule
      # Завершаем ввод правил
      if session.data[:word] && session.data[:rules]
        @bot.api.send_message(
          chat_id: chat_id,
          text: "Ввод правил завершён.",
          )
      else
        session.mode = nil
        @bot.api.send_message(
          chat_id: chat_id,
          text: "Ввод правил завершён.\nЧтобы применить алгоритм, введите слово (кнопка 'Ввести слово').",
          reply_markup: main_menu_keyboard
        )
      end
    elsif mode == :waiting_for_word
      # Завершаем ввод слова
      if session.data[:word] && session.data[:rules]
        @bot.api.send_message(
          chat_id: chat_id,
          text: "Слово сохранено.",
          )
      else
        session.mode = nil
        if session.data[:word]
          @bot.api.send_message(
            chat_id: chat_id,
            text: "Слово сохранено. Теперь введите систему правил (кнопка 'Ввести систему').",
            reply_markup: main_menu_keyboard
          )
        else
          @bot.api.send_message(
            chat_id: chat_id,
            text: "Слово не было введено.",
            reply_markup: main_menu_keyboard
          )
        end

      end
      # else
      # Если не в режиме ввода – просто показать меню
      # show_main_menu(chat_id)
      # return
    end
    show_main_menu(chat_id)
    save_sessions
  end

  # ---- Обработка ввода данных ----
  def process_rule_input(chat_id, rule_text)
    session = @sessions[chat_id]
    puts "#{chat_id}- Обработка ввода правил"

    case rule_text
    when 'Завершить ввод'
      finish_input(chat_id)
      return
    when 'Удалить последнее правило'
      delete_last_rule(chat_id)
      return
    when 'Очистить систему'
      clear_system(chat_id)
      return
    when 'Главное меню'
      session.mode = nil
      session.data[:rules] = []
      show_main_menu(chat_id)
      return
    end

    begin
      rule = CoolRubyGem::Rule.new(rule_text).to_s
      session.data[:rules] << rule
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Правило добавлено: #{rule}\nТекущая система: #{session.data[:rules].join(', ')}\n\nВведите ещё правило или нажмите 'Завершить ввод'."
      )
    rescue StandardError => e
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Ошибка: #{e.message}\nПопробуйте снова. Формат: a->b или a->.b"
      )
    end
    save_sessions
  end

  def process_word_input(chat_id, word)
    puts "#{chat_id}- Обработка ввода слов"
    session = @sessions[chat_id]

    if word == 'Завершить ввод'
      finish_input(chat_id)
      return
    elsif word == 'Главное меню'
      finish_input(chat_id)
      show_main_menu(chat_id)
      return
    elsif word == 'Ввести другое слово'
      session.data[:word] = nil
      start_word_input(chat_id)
      return
    end

    session.data[:word] = word
    @bot.api.send_message(
      chat_id: chat_id,
      text: "Слово #{word} сохранено. \n\n
Нажмите 'Ввести другое слово' для ввода другого слова.\n
Когда закончите, нажмите кнопку 'Завершить ввод'.\n
Нажмите 'Главное меню', если не хотите сохранять изменения, вы перейдете в главное меню.",
      )
    cancel_word_keyboard
    save_sessions
  end

  def apply_algorithm(chat_id)
    puts "#{chat_id}- Результат подстановки"

    session = @sessions[chat_id]

    # Проверка наличия правил
    if session.data[:rules].nil? || session.data[:rules].empty?
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Сначала введите систему правил (кнопка 'Ввести систему').",
        reply_markup: main_menu_keyboard
      )
      return
    end

    # Проверка наличия слова
    if session.data[:word].nil? || session.data[:word].empty?
      @bot.api.send_message(
        chat_id: chat_id,
        text: "Сначала введите исходное слово (кнопка 'Ввести слово').",
        reply_markup: main_menu_keyboard
      )
      return
    end

    rules = CoolRubyGem::System.new(session.data[:rules])
    word = session.data[:word].dup

    res = rules.result(word)

    @bot.api.send_message(
      chat_id: chat_id,
      text: "Алгоритм выполняется...\n\nСистема: #{rules}\nИсходное слово: #{word}\nРезультат: #{res}",
      reply_markup: main_menu_keyboard
    )
    session.mode = nil
    save_sessions
    show_main_menu(chat_id)
  end

  # ---- Клавиатуры ----
  def main_menu_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [{ text: 'Ввести систему' }, { text: 'Ввести слово' }],
        [{ text: 'Показать результат' }, { text: 'Пошаговое решение' }],
        [{ text: 'Сбросить всё' }]
      ],
      resize_keyboard: true,
      one_time_keyboard: false
    )
  end

  def cancel_word_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [{ text: 'Завершить ввод' }],
        [{ text: 'Ввести другое слово' }],
        [{ text: 'Главное меню' }]
      ],
      resize_keyboard: true,
      one_time_keyboard: false
    )
  end


  def system_keyboard
    Telegram::Bot::Types::ReplyKeyboardMarkup.new(
      keyboard: [
        [{ text: 'Удалить последнее правило' }],
        [{ text: 'Очистить систему' }],
        [{ text: 'Завершить ввод' }],
        [{ text: 'Главное меню' }]
      ],
      resize_keyboard: true,
      one_time_keyboard: false
    )
  end
end

if __FILE__ == $0
  MarkovBot.new(TOKEN).start
end