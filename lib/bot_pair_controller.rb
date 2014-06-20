#!/usr/bin/env ruby

require_relative 'bot_db_access'
require_relative 'bot_pair_protocol_template'
require 'blather/client/dsl'
require 'rexml/document'
require 'yaml'

BOT_ACCOUNT_CONFIG_FILE = '../config/bot_account_config.yml'

KPAIR_START_REQUEST = 'pair_start_request'
KPAIR_COMPLETED_SUCCESS_RESPONSE = 'pair_completed_success_response'
KPAIR_COMPLETED_FAILURE_RESPONSE = 'pair_completed_failure_response'
KPAIR_TIMEOUT_SUCCESS_RESPONSE = 'pair_timeout_success_response'
KPAIR_TIMEOUT_FAILURE_RESPONSE = 'pair_timeout_failure_response'

module PairController
  extend Blather::DSL
  
  def self.new
    @db_conn = nil
    @bot_xmpp_account = nil
    config_file = File.join(File.dirname(__FILE__), BOT_ACCOUNT_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    @bot_xmpp_account = config['bot_xmpp_account']
    
    setup config['bot_xmpp_account'], config['bot_xmpp_password']
    puts 'Init listen account '
    
    @db_conn = BotDBAccess.new
  end
  
  def self.run
    EM.run { client.run }
  end
  
  def self.send_request(job, info)
    
    case job
      when KPAIR_START_REQUEST
        msg = PAIR_START_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
      
      when KPAIR_COMPLETED_SUCCESS_RESPONSE
        msg = PAIR_COMPLETED_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, 'clshang@ecoworkinc.com', info[:session_id]]
        write_to_stream msg
      
      when KPAIR_COMPLETED_FAILURE_RESPONSE
        msg = PAIR_COMPLETED_FAILURE_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, 999, info[:session_id]]
        write_to_stream msg
        
      when KPAIR_TIMEOUT_SUCCESS_RESPONSE
        msg = PAIR_TIMEOUT_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
      
      when KPAIR_TIMEOUT_FAILURE_RESPONSE
        msg = PAIR_TIMEOUT_FAILURE_FAILURE % [info[:xmpp_account], @bot_xmpp_account, 999, info[:session_id]]
        write_to_stream msg
    end
  end
  
  #subscription :request? do |s|
  #  write_to_stream s.approve!
  #end
  
  message :normal? do |msg|
    
    if msg.form.result? then
      title = msg.form.title
      puts 'Receive result message ' + title
      
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'start' == action then
            data = {id: session_id, status: 1}
            isSuccess = @db_conn.db_pairing_session_update(data)
            puts 'Update pair session wait success' if isSuccess
          end
        when 'unpair'
        when 'upnp'
          puts 'Receive upnp request'
        when 'ddns'
          puts 'Receive ddns request'  
      end
        
    elsif msg.form.submit? then
      title = msg.form.title
      puts 'Receive submit message ' + title
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'completed' == action then
            device = @db_conn.db_pairing_session_access_by_id(session_id)
            expire_time = device[:expire_at]
            
            if expire_time > DateTime.now 
              data = {id: session_id, status: 2}
              isSuccess = @db_conn.db_pairing_session_update(data)
              puts 'Update pair session completed success' if isSuccess
              
              isSuccess = @db_conn.db_pairing_insert(device[:user_id], device[:device_id])
              puts 'Insert paired data success' if isSuccess
            
              info = {xmpp_account: msg.from, session_id: session_id}
              send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
              puts 'Send to device completed success'
            else
              data = {id: session_id, status: 4}
              isSuccess = @db_conn.db_pairing_session_update(data)
              puts 'Update pair session completed time out' if isSuccess
            
              info = {xmpp_account: msg.from, session_id: session_id}
              send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
              puts 'Send to device completed success'
            end
          end
          
          if 'cancel' == action then # for timeout request
            data = {id: session_id, status: 4}
            isSuccess = @db_conn.db_pairing_session_update(data)
            puts 'Update pair session time out' if isSuccess
            
            if isSuccess
              info = {xmpp_account: msg.from, session_id: session_id}
              send_request(KPAIR_TIMEOUT_SUCCESS_RESPONSE, info)
              puts 'Send to device time out success'
            else
              info = {xmpp_account: msg.from, session_id: session_id}
              send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
              puts 'Send to device time out failure'
            end
          end
        when 'unpair'
        when 'upnp'
          puts 'Receive upnp request'
        when 'ddns'
          puts 'Receive ddns request'  
      end
      
    elsif msg.form.cancel? then
      title = msg.form.title
      puts 'Receive cancel message ' + title
      
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'start' == action then
            data = {id: session_id, status: 4}
            isSuccess = @db_conn.db_pairing_session_update(data)
            puts 'Update pair session failue success' if isSuccess
          end
        when 'unpair'
        when 'upnp'
          puts 'Receive upnp request'
        when 'ddns'
          puts 'Receive ddns request'  
      end
    else
    end
    #write_to_stream msg.reply
  end
end