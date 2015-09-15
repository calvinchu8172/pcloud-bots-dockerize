#!/usr/bin/env ruby

require_relative 'lib/bot_xmpp_db_access'

require 'rubygems'
require 'active_record'
require 'blather/client'
require './lib/bot_pair_protocol_template'
require './lib/bot_xmpp_spec_protocol_template'
require 'pry'
# XMPP_ACCOUNT = 'd099789665701-a123456@192.168.50.10/device'
# XMPP_PASSWORD = 'kxxNQJBLHZ'

XMPP_ACCOUNT = 'd0023f8311041-tempserialnum0000@localhost/device'
XMPP_PASSWORD = '8kP0wNjEkA'
USER_EMAIL = 'spjay1@gmail.com'

username = 'd0023f8311041-tempserialnum0000'
xmpp_db = BotXmppDBAccess.new
password = XMPP_User.find_by(username: username).password

XMPP_PASSWORD = "#{password}"

# XMPP_ACCOUNT = 'd099789665701-a123456@beta.xmpp.zyxel.com/device'
# XMPP_PASSWORD = 'IxWHNXEVYq'

# XMPP_ACCOUNT = 'd099789665701-a123456@xmpp.zyxel.com/device'
# XMPP_PASSWORD = 'MDGJKQQcOz'

puts '%s start connect to XMPP server' % XMPP_ACCOUNT

setup XMPP_ACCOUNT , XMPP_PASSWORD

puts 'Waiting XMPP connection ready ...'

when_ready { puts "Connected !" }

msg_counter = 0

message :normal?, proc {|m| m.form.submit? && 'pair' == m.form.title} do |msg|
  puts 'Receive PAIRING START request from %s' % msg.from.to_s

  session_id = msg.thread
  rmsg = PAIR_START_SUCCESS_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send PAIRING COMPLETED SUCCESS response to %s' % msg.from.to_s

  sleep(10)

  rmsg = PAIR_COMPLETED_REQUEST % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg

  puts 'Receive PAIRING request and response success to %s' % msg.from.to_s
end

message :normal?, proc {|m| m.form.submit? && 'unpair' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = UNPAIR_RESPONSE_SUCCESS % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send UNPAIR SUCCESS response to %s' % msg.from.to_s
end

message :normal?, proc {|m| m.form.submit? && 'get_upnp_service' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = UPNP_ASK_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send UNPNP SETTING response to %s' % msg.from.to_s
end

message :normal?, proc {|m| m.form.submit? && 'set_upnp_service' == m.form.title} do |msg|
  session_id = msg.thread
  #rmsg = UPNP_ASK_SET_RESPONSE_FAILURE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  rmsg = UPNP_ASK_SET_RESPONSE_FAILURE % [msg.from.to_s, XMPP_ACCOUNT, session_id]

  write_to_stream rmsg
  #puts 'Send UNPNP SETTING SUCCESS response to %s' % msg.from.to_s
  puts 'Send UNPNP SETTING FAILURE response to %s' % msg.from.to_s

end

# form DDNS
message :normal?, proc {|m| m.form.submit? && 'config' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = DDNS_SETTING_SUCCESS_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send DDNS SUCCESS response to %s' % msg.from.to_s
end

message :normal?, proc {|m| m.form.submit? && 'bot_set_share_permission' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = PERMISSION_SETTING_SUCCESS_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send PERMISSION SETTING SUCCESS response to %s' % msg.from.to_s
end

message :normal?, proc {|m| m.form.submit? && 'bot_get_device_information' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = DEVICE_INFO_RESPONSE_SUCCESS % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send DEVICE INFORMATION SUCCESS response to %s' % msg.from.to_s
end

message :normal?, proc {|m| m.form.submit? && 'bot_led_indicator' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = LED_INDICATOR_REQUEST_FAILURE_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, '100', session_id]
  write_to_stream rmsg
  puts 'Send LED INDICATOR FAILURE response to %s' % msg.from.to_s
end


message :normal?, proc {|m| m.form.submit? && 'bot_get_package_list' == m.form.title} do |msg|
  session_id = msg.thread
  rmsg = PACKAGE_ASK_REQUEST_SUCCESS % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  puts 'Send PACKAGE LIST  response to %s' % msg.from.to_s
  msg_counter  = msg_counter + 1
  #puts msg_counter
  #puts Time.now.to_s
end


message :normal?, proc {|m| m.form.submit? && 'bot_set_package_list' == m.form.title} do |msg|
  session_id = msg.thread
  sleep( 10 )
  #rmsg = SET_PACKAGE_REQUEST_FAILUR_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  rmsg = SET_PACKAGE_REQUEST_SUCCESS_RESPONSE % [msg.from.to_s, XMPP_ACCOUNT, session_id]
  write_to_stream rmsg
  #puts 'Send PACKAGE SETTING FAILURE response to %s' % msg.from.to_s
  puts 'Send PACKAGE SETTING Success response to %s' % msg.from.to_s

end