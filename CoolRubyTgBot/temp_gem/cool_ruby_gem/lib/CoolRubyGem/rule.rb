# frozen_string_literal: true
module CoolRubyGem
  class Rule
    def initialize(rule)
      @is_end = rule.match?(/->\./)

      rule = rule.gsub(' ', '')

      unless rule.match?(/^[a-zA-Z]+->\.?[a-zA-Z]*$/)
        raise "Error! Incorrect rule format: '#{rule}'"
      end

      rule = rule.gsub('.', '') if @is_end

      rule = rule.split('->')
      @x = rule[0]
      @y = rule[1]

    end

    def to_s
      "#{@x}->#{@is_end ? '.' : ''}#{@y}"
    end

    def is_end?
      @is_end
    end

    def can_be_used?(word)
      return true if @x == 'e'
      word.match?(@x)
    end

    def apply(word)

      return word unless can_be_used?(word)

      if @x == 'e' && @y == 'e'
        word
      elsif @x == 'e'
        @y + word
      elsif @y == 'e'
        word.sub(@x, '')
      else
        word.sub(@x, @y)
      end

    end

  end
end