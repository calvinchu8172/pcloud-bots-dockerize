require_relative 'lib/bot_xmpp_db_access'
require_relative 'lib/bot_redis_access'

require 'rubygems'
require 'xmpp4r/client'
require 'active_record'
require 'blather/client'
require 'blather/client/dsl'
require 'multi_xml'
require 'fluent-logger'
require './lib/bot_pair_protocol_template'
require './lib/bot_xmpp_spec_protocol_template'
require './lib/bot_xmpp_health_check_template'
require 'pry'
include Jabber

FLUENT_BOT_SYSINFO = "bot.sys-info"

Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)

bot_xmpp_domain = 'localhost'
# bot_xmpp_user = 'bot1'

# bot_xmpp_account = "#{bot_xmpp_user}@#{bot_xmpp_domain}"

device_xmpp_user = 'd0023f8311041-tempserialnum0000'
device_xmpp_domain = bot_xmpp_domain
@device_xmpp_account = "#{device_xmpp_user}@#{device_xmpp_domain}"
xmpp_db = BotXmppDBAccess.new
@device_xmpp_password = XMPP_User.find_by(username: device_xmpp_user).password

bot_xmpp_users = XMPP_User.where( "username like ?", "%bot%" )
# c = XMPP_User.find(:all, :conditions => ["username like ?","%bot%"])

bot_xmpp_usernames = []
bot_xmpp_users.each do |bot_xmpp_user|
  if bot_xmpp_user.username =~ /^bot([0-9]{1})$/
    bot_xmpp_usernames << "#{bot_xmpp_user.username}@#{bot_xmpp_domain}"
  end
end

session_id = Time.now.to_i

# @health_check_msg = HEALTH_CHECK_SEND_RESPONSE % [bot_xmpp_usernames[0], @device_xmpp_account, session_id] # to bot, from device, thread_id
MultiXml.parser = :rexml
# xml = MultiXml.parse(@health_check_msg.to_s)
# xml['message']['to']
# xml['message']['x']['title']

# binding.pry

@sent_bots = []
# @received_bots = []

puts '%s start connect to XMPP server' % @device_xmpp_account

setup @device_xmpp_account , @device_xmpp_password

puts 'Waiting XMPP connection ready ...'

when_ready do
  puts "Connected !"
  i = 0
  loop do
  # while (Time.now.sec == 10 || Time.now.sec == 30 || Time.now.sec == 50)
    bot_xmpp_usernames.each do |bot_xmpp_username|
      @health_check_msg = HEALTH_CHECK_SEND_RESPONSE % [bot_xmpp_username, @device_xmpp_account, session_id] # to bot, from device, thread_id
      xml = MultiXml.parse(@health_check_msg.to_s)
      @to = xml['message']['to']
      @from = xml['message']['from']
      @title = xml['message']['x']['title']
      write_to_stream @health_check_msg
      # puts "sent #{title} to #{to}"
      @sent_bots << @to
    end

    puts "sent #{@sent_bots}"
    Fluent::Logger.post( FLUENT_BOT_SYSINFO, { event: 'bot_health_check',
                                               direction: 'Health_Check->Bot',
                                               to: @sent_bots,
                                               # from: @from,
                                               message: @title
                                              } )
    @sent_bots.clear

    i += 1
    break if i > 10
    sleep 3
  end

end

# HANDLER: bot_health_check_send
message :normal?, proc {|m| 'bot_health_check_success' == m.form.title } do |msg|
  # puts 'OK!!'

  xml = MultiXml.parse msg.to_s
  title = xml['message']['x']['title']
  to = xml['message']['to']
  from = xml['message']['from']
  puts "Successfully received from #{from}"
  Fluent::Logger.post( FLUENT_BOT_SYSINFO, { event: 'bot_health_check',
                                             direction: 'Bot->Health_Check',
                                             to: to,
                                             from: from,
                                             message: title
                                            } )

  # @received_bots << from

end
