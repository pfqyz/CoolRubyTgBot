# frozen_string_literal: true
module CoolRubyGem
  class Rule
    def initialize(rule)
      # Убираем пробелы
      rule = rule.gsub(' ', '')

      # Проверяем, является ли правило завершающим (есть . после ->)
      @is_end = rule.include?('->.')

      # Проверка формата с учётом эпсилон
      # Допустимые форматы:
      #   a->b      (обычное)
      #   a->.b     (завершающее)
      #   a->e      (удаление a)
      #   e->b      (вставка b в начало)
      #   a->       (удаление a, короткая запись)
      #   e->       (вставка пустоты - ничего не делает)
      unless rule.match?(/^[a-zA-Z]*->\.?[a-zA-Ze]*$/)
        raise "Error! Incorrect rule format: '#{rule}'"
      end

      # Убираем точку, если она была в правиле
      rule = rule.gsub('.', '') if @is_end

      # Разделяем левую и правую части
      parts = rule.split('->')
      @x = parts[0]
      @y = parts[1] || ''  # если правой части нет, то пустая строка

      # Преобразуем эпсилон в пустую строку
      @x = '' if @x == 'e'
      @y = '' if @y == 'e'
    end

    def to_s
      left = @x.empty? ? 'e' : @x
      right = @y.empty? ? 'e' : @y
      arrow = @is_end ? '->.' : '->'
      "#{left}#{arrow}#{right}"
    end

    def is_end?
      @is_end
    end

    def can_be_used?(word)
      # Если левая часть пустая (эпсилон) — правило всегда применимо
      return true if @x.empty?
      # Иначе проверяем, содержится ли левая часть в слове
      word.include?(@x)
    end

    def apply(word)
      return word unless can_be_used?(word)

      # Случай 1: левая часть пустая (правило e->b) — вставляем правую часть в начало
      if @x.empty?
        return @y + word
      end

      # Случай 2: правая часть пустая (правило a->e) — удаляем левую часть
      if @y.empty?
        return word.sub(@x, '')
      end

      # Случай 3: обычная замена a->b
      word.sub(@x, @y)
    end
  end
end
