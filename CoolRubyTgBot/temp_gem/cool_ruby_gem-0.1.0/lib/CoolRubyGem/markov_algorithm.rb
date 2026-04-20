# frozen_string_literal: true

module CoolRubyGem
  # Скажем, что систему уравнений мы будем обозначать так
  # {
  # ...
  # }
  # каждое правило из системы будет иметь вид:
  # x -> y; или x ->. y;
  # файл будет иметь вид:
  # система:{}
  # а затем слова для преобразования пример: aaa bbb ababa babab aabbaabbaabb
  # пока не встретиться другая система мы будем обрабатывать эти слова по прошлой системе
  # если она<другая система> встретилась, то считываем ее и обрабатываем следующие за ней слова
  # каждое правило вида x -> y; или x ->. y; будет иметь такой и только такой вид
  # (\n после каждого правила не обязателен, но желателен).
  # ///////////////////////////////////////////////////
  # договоримся, что в славах не может быть символа e,
  # так как он нам понадобился для реализации пустого элемента в функциях
  # в случае его использования будет выброшено исключение



  require_relative 'rule'
  require_relative 'system'

  require_relative 'rule'
  require_relative 'system'

  w = 'xxyy'

  s = System.new(['y->x', 'x->.yy'])
  puts "System: #{s}"
  puts "Word: #{w}"
  puts "Result: #{s.step_by_step_solution(w)}"
  puts "//////////////"

  s = System.new(['x->y', 'y->.x', 'x->.yy'])
  puts "System: #{s}"
  puts "Word: #{w}"
  puts "Result: #{s.step_by_step_solution(w)}"
  puts "//////////////"

  s = System.new(['x->y', 'e->y', 'x->.yy'])
  puts "System: #{s}"
  puts "Word: #{w}"
  puts "Result: #{s.step_by_step_solution(w)}"
  puts "//////////////"

  s = System.new(['x->y', 'y->e', 'x->.yy'])
  puts "System: #{s}"
  puts "Word: #{w}"
  puts "Result: #{s.step_by_step_solution(w)}"
  puts "//////////////"

  puts "//////////////"

  system = System.new(['x->y', 'x->.yy'])
  puts system.step_by_step_solution('xxyy')

  puts
  puts
  puts "//////Parsing file part////////"

  # Функция парсинга файла
  def self.parsing(file_path)
    content = File.read(file_path, encoding: 'UTF-8')
    # Удаляем комментарии
    content = content.gsub(%r{//.*$}, '')

    # Разбиваем на блоки
    blocks = content.scan(/система:\{(.*?)\}(.*?)(?=\n\s*система:|\z)/m)

    rules_arrays = []
    strings_arrays = []

    blocks.each do |rules_str, words_str|
      # Парсим правила
      rules = rules_str.strip.split(/\s*;\s*/).reject(&:empty?)
      rules_arrays << rules

      # Парсим слова
      words = words_str.strip.split(/\s+/).reject(&:empty?)
      strings_arrays << words
    end

    [rules_arrays, strings_arrays]
  end

  base_path = File.join(__dir__, '..', '..', 'Config')

  names_f = ["BadFile.txt", "GoodFile.txt", "ErrorFile.txt"]
  names_f.each do |name|
    puts "//////Parsing and test '#{name}' file////////"
    file_path = File.join(base_path, name)

    unless File.exist?(file_path)
      puts "Файл не найден: #{file_path}"
      next
    end

    begin
      rules_arrays, strings_arrays = parsing(file_path)

      rules_arrays.each_with_index do |rules, idx|
        puts "Система #{idx + 1}: { #{rules.join('; ')} }"

        system = System.new(rules)

        strings_arrays[idx].each do |word|
          result = system.result(word)
          puts "  #{word} -> #{result}"
        end

        puts
      end
    rescue => e
      puts "Ошибка: #{e.message}"
    end
  end

end