# frozen_string_literal: true

module CoolRubyGem
  def parsing(file_path)
    rules_arrays = []
    strings_arrays = []
    File.foreach(file_path, chomp: true) do |line|
      next if line.strip.empty?
      line = line.strip
      # Разделяю с помощью регулярки
      match = line.match(/\A\s*\{(.*?)\}\s*(.*?)\s*\z/)
      raise "Invalid line format: #{line}" unless match

      rules_part = match[1]   # внутри {}
      strings_part = match[2] # после {}

      # Делаю парсинг правила
      help_rules = rules_part.split(';').map(&:strip).reject(&:empty?)
      clean_rules = help_rules.map do |rule|
        # Удаляю лишние пробелы внутри правила
        rule = rule.gsub(/\s+/, '')
        # Проверяю формат правила что то -> что то (с точкой)
        unless rule.match?(/\A[A-Za-z]+->[A-Za-z.]+\z/)
          raise "Invalid rule format: #{rule}"
        end
        rule
      end

      # Разбиваю по пробелам, удаляю пустые
      if strings_part.include?(',')
        raw_strings = strings_part.strip.split(',', -1)
        strings = raw_strings.map(&:strip)
      else
        strings = strings_part.strip.split(/\s+/).reject(&:empty?)
      end

      raise "Nothing found after rules" if strings.empty?

      # Проверка строк: пустые строки (пустые слова) допустимы
      strings.each do |str|
        unless str.empty? || str.match?(/\A[A-Za-z]+\z/)
          raise "Invalid string content: #{str} (only letters!)"
        end
      end
      rules_arrays << clean_rules
      strings_arrays << strings
    end

    [rules_arrays, strings_arrays]

  end
end