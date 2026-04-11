# frozen_string_literal: true
require 'telegram/bot'

#bot = TelegramBot.new(token: '8785997708:AAFzO-M6h4Qp7gq8RDPKEdlGNo4JsmG23pk')

token = '8785997708:AAFzO-M6h4Qp7gq8RDPKEdlGNo4JsmG23pk'

Telegram::Bot::Client.run(token) do |bot|
  bot.listen do |message|
    case message.text
    when '/start'
      puts '/start'
      bot.api.send_message(chat_id: message.chat.id, text: "Привет, #{message.from.first_name}, это бот для решения алгоритмов Маркова!\nНапиши свое входное слово: ")
    when '/stop'
      puts '/stop'
      bot.api.send_message(chat_id: message.chat.id, text: "Bye, #{message.from.first_name}")
    end
  end
end
#{message.from.first_name}
#bot.run