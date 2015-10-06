require_relative 'lib/bot_xmpp_db_access'
require_relative 'lib/bot_xmpp_controller'
require 'rubygems'
require 'eventmachine'
require 'blather/client/dsl'
require 'multi_xml'
require 'pry'
require './lib/bot_xmpp_health_check_template'

FLUENT_BOT_SYSINFO = "bot.sys-info"
FLUENT_BOT_SYSALERT = "bot.sys-alert"

Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)

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
@xmpp_resource_id = '/device'

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
  }

  App.disconnected {
    # App.run
    Fluent::Logger.post(FLUENT_BOT_SYSALERT, { event: 'bot_health_check',
                                               direction: 'N/A',
                                               to: 'N/A',
                                               from: @bot_xmpp_account,
                                               id: 'N/A',
                                               full_domain: 'N/A',
                                               message:"%s reconnect XMPP server ..." % client.jid.to_s,
                                               data: 'N/A'
                                              } )
    begin
      client.connect
    rescue Exception => error
      puts error
    end
  }

  # p = EM::PeriodicTimer.new(1) do
  #   puts "Tick ..."
  # end

  EM.add_timer(1) do
    bot_xmpp_usernames.each do |bot_xmpp_username|
      @health_check_msg = HEALTH_CHECK_SEND_RESPONSE % [bot_xmpp_username, @bot_health_check_account, @session_id] # to bot, from device, thread_id
      App.write_to_stream(@health_check_msg)
      xml = MultiXml.parse @health_check_msg.to_s
      title = xml['message']['x']['title']
      to = xml['message']['to']
      from = xml['message']['from']
      puts "sent #{title} to #{to}"
      Fluent::Logger.post( FLUENT_BOT_SYSINFO, { event: 'bot_health_check',
                                                 direction: 'Health_Check->Bot',
                                                 to: to,
                                                 from: from,
                                                 message: title
                                                } )
    end
  end


  df = EM::DefaultDeferrable.new

  EM.add_timer(6) do
    @remain_bot_xmpp_users = bot_xmpp_usernames - @received_bot_xmpp_users
    df.set_deferred_status :succeeded, @remain_bot_xmpp_users
  end

  df.callback do |x|
    puts "Timeout from #{x}"
    EM.stop
  end

  App.message :normal?, proc {|m| 'bot_health_check_success' == m.form.title } do |msg|
    xml = MultiXml.parse msg.to_s
    title = xml['message']['x']['title']
    to = xml['message']['to']
    from = xml['message']['from'].split('/')[0] #remove resource name
    puts "Successfully received from #{from}"
    @received_bot_xmpp_users << from
    puts @received_bot_xmpp_users
    Fluent::Logger.post( FLUENT_BOT_SYSINFO, { event: 'bot_health_check',
                                               direction: 'Bot->Health_Check',
                                               to: to,
                                               from: from,
                                               message: title
                                              } )
  end

end

