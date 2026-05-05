# frozen_string_literal: true

module CoolRubyGem
  class System
    include Enumerable

    def initialize(rules)
      @rules = []
      rules.each do |r|
        @rules.append(Rule.new(r))
      end
    end

    def <<(val)
      @rules << val
    end

    def each(&block)
      @rules.each(&block)
    end

    def to_s
      str = '{ '
      @rules.each do |r|
        str += "#{r.to_s}; "
      end
      str + '}'
    end

    def step_by_step_solution(word, max_steps: 1000, max_length: 10000)
      # Убираем проверку на 'e' - теперь e может быть обычной буквой
      # Эпсилон в правилах обрабатывается на уровне Rule
      w = word.dup
      puts "#{w} ->"
      steps = 0
      history = {}
      while steps < max_steps
        if w.length > max_length
          puts "Possible infinite loop"
          return w
        end
        if history.key?(w)
          puts "Possible infinite loop"
          return w
        end
        history[w] = true
        applied = false
        @rules.each do |rule|
          if rule.can_be_used?(w)
            new_w = rule.apply(w)
            steps += 1
            if new_w == w && !rule.is_end?
              puts "Possible infinite loop"
              return w
            end
            w = new_w
            if rule.is_end?
              puts " #{w}."
              return w
            end
            puts " #{w} ->"
            applied = true
            break
          end
        end
        break unless applied
      end
      if steps >= max_steps
        puts "Possible infinite loop"
      end
      w
    end

    def result(word, max_steps: 1000, max_length: 10000)
      # Убираем проверку на 'e' - теперь e может быть обычной буквой
      # Эпсилон в правилах обрабатывается на уровне Rule
      w = word.dup
      steps = 0
      history = {}
      while steps < max_steps
        if w.length > max_length
          puts "Possible infinite loop"
          return w
        end
        if history.key?(w)
          puts "Possible infinite loop"
          return w
        end
        history[w] = true
        applied = false
        @rules.each do |rule|
          if rule.can_be_used?(w)
            new_w = rule.apply(w)
            steps += 1
            if new_w == w && !rule.is_end?
              puts "Possible infinite loop"
              return w
            end
            w = new_w
            if rule.is_end?
              return w
            end
            applied = true
            break
          end
        end
        break unless applied
      end
      if steps >= max_steps
        puts "Possible infinite loop"
      end
      w
    end
  end
end
