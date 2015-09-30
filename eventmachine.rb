require_relative 'lib/bot_xmpp_db_access'
require_relative 'lib/bot_xmpp_controller'
require 'rubygems'
require 'eventmachine'
require 'blather/client/dsl'
require 'multi_xml'
require 'pry'
require './lib/bot_xmpp_health_check_template'

xmpp_connect_ready = FALSE
threads = []
MultiXml.parser = :rexml

@xmpp_db = BotXmppDBAccess.new
XMPP_User.create(username: 'bot_health_check', password: '123456') if XMPP_User.find_by(username: 'bot_health_check') == nil
bot_health_check_user = 'bot_health_check'
bot_xmpp_domain = 'localhost'
@bot_health_check_account = "#{bot_health_check_user}@#{bot_xmpp_domain}"
@bot_health_check_password = XMPP_User.find_by(username: bot_health_check_user).password
@session_id = Time.now.to_i
# @bot_xmpp_account = "bot1@localhost"
# @health_check_msg = HEALTH_CHECK_SEND_RESPONSE % [@bot_xmpp_account, @bot_health_check_account, session_id] # to bot, from device, thread_id


# select bots in XMPP db
bot_xmpp_users = XMPP_User.where( "username like ?", "%bot%" )
bot_xmpp_usernames = []
bot_xmpp_users.each do |bot_xmpp_user|
  if bot_xmpp_user.username =~ /^bot([0-9]{1})$/
    bot_xmpp_usernames << "#{bot_xmpp_user.username}@#{bot_xmpp_domain}"
  end
end

@received_bot_xmpp_users = []

module App
  extend Blather::DSL

  # def self.run
  #   EM.run { client.run }
  # end

  # def self.run
  #   EM.run {
  #     # EM.add_periodic_timer(0.3){
  #     #   puts 'tick 0.3s'
  #     # }
  #     bot_health_check_account = 'bot_health_check@localhost'
  #     bot_health_check_password = XMPP_User.find_by(username: 'bot_health_check').password

  #     setup bot_health_check_account, bot_health_check_password
  #     client.run
  #     puts 'login'

      # when_ready {
      #   puts 'ready...'
      #   xmpp_connect_ready = TRUE
      #   health_check_msg = HEALTH_CHECK_SEND_RESPONSE % ["bot1@localhost", @bot_health_check_account, Time.now.to_i] # to bot, from device, thread_id
      #   write_to_stream(health_check_msg)
      #   # binding.pry
      #   puts "go"
      # }

  #     puts "sent"
  #   }
  # end

  #sender
  # def self.send_request msg
  #   xml = MultiXml.parse msg.to_s
  #   to = xml['message']['to']
  #   write_to_stream msg
  #   puts "Successfully send to #{to}"
  # end

  disconnected {
   client.run
 }

# HANDLER: bot_health_check_send
  # message :normal?, proc {|m| 'bot_health_check_success' == m.form.title } do |msg|
  #   xml = MultiXml.parse msg.to_s
  #   from = xml['message']['from']
  #   puts "Successfully received from #{from}"
  # end

end

# binding.pry

EM.run do

  App.setup @bot_health_check_account, @bot_health_check_password; puts 'login'

  App.run

  App.when_ready {
    puts 'connected!'
    xmpp_connect_ready = TRUE
    bot_xmpp_usernames.each do |bot_xmpp_username|
      @health_check_msg = HEALTH_CHECK_SEND_RESPONSE % [bot_xmpp_username, @bot_health_check_account, @session_id] # to bot, from device, thread_id
      App.write_to_stream(@health_check_msg)
      xml = MultiXml.parse @health_check_msg.to_s
      to = xml['message']['to']
      from = xml['message']['from']
      title = xml['message']['x']['title']
      puts "sent #{title} to #{to}"
    end
  }

  App.disconnected { App.run }

  p = EM::PeriodicTimer.new(1) do
    puts "Tick ..."
  end

  App.message :normal?, proc {|m| 'bot_health_check_success' == m.form.title } do |msg|
    xml = MultiXml.parse msg.to_s
    from = xml['message']['from'].split('/')[0] #remove resource name
    puts "Successfully received from #{from}"
    @received_bot_xmpp_users << from
    # puts @received_bot_xmpp_users
  end

  df = EM::DefaultDeferrable.new

  EM.add_timer(5) do
    @remain_bot_xmpp_users = bot_xmpp_usernames - @received_bot_xmpp_users
    df.set_deferred_status :succeeded, @remain_bot_xmpp_users
  end

  df.callback do |x|
    puts "Timeout from #{x}"
    EM.stop
  end

end
