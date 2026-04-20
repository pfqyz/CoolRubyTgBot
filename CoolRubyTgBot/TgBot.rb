# frozen_string_literal: true
require 'CoolRubyGem'
require 'telegram/bot'
#bot = TelegramBot.new(token: '8785997708:AAFzO-M6h4Qp7gq8RDPKEdlGNo4JsmG23pk')

token = '8785997708:AAFzO-M6h4Qp7gq8RDPKEdlGNo4JsmG23pk'


Telegram::Bot::Client.run(token) do |bot|
  bot.logger.info('Bot has been started')
  bot.listen do |message|
    flag = false
    case message.text
    when '/start' #or '/start'
      puts '/start'
      bot.api.send_message(chat_id: message.chat.id, text: "Привет, #{message.from.first_name}, это бот для решения алгоритмов Маркова!")
      question = 'Что делать?'
      answers =
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [{ text: 'Ввести систему' }, { text: 'Ввести слово' }]
          ],
          one_time_keyboard: true
        )
      bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)
    when 'Ввести систему'
      flag = true
      puts 'Ввести систему'
      question = '?'
      system = []

      answers =
        Telegram::Bot::Types::ReplyKeyboardMarkup.new(
          keyboard: [
            [ { text: 'Добавить правило' }, { text: 'Ввод закончен' }, { text: 'Добавить правило' }]
          ],
          one_time_keyboard: true
        )

      bot.api.send_message(chat_id: message.chat.id, text: question, reply_markup: answers)

      if message != 'Ввод закончен' and flag
        begin
          r = CoolRubyGem::Rule.new(message)
          system << r
        rescue => e
          bot.api.send_message(chat_id: message.chat.id, text: "Ошибка: #{e.message}")
        end

        puts 'The rule is added'
        rules = '{'
        system.each { |rule| rules +=rule.to_s +";\n"}
        rules +='}'
        bot.api.send_message(chat_id: message.chat.id, text: 'Ваша система выглядит так:'+"\n"+rules )

      end

      if message == 'Ввод закончен'
        puts 'Ввод системы закончен'
        flag = false
      end


    when 'Ввести слово'
      puts 'Ввести слово'
    when '/stop'
      puts '/stop'
      bot.api.send_message(chat_id: message.chat.id, text: "Пока-пока, #{message.from.first_name}")
    end
  end
end
=begin
Telegram::Bot::Client.run(token) do |bot|

end
=end
#{message.from.first_name}
#bot.run