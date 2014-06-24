#!/usr/bin/env ruby

require_relative 'bot_db_access'
require_relative 'bot_pair_protocol_template'
require 'blather/client/dsl'
require 'multi_xml'
require 'json'
require 'yaml'

BOT_ACCOUNT_CONFIG_FILE = '../config/bot_account_config.yml'

KPAIR_START_REQUEST = 'pair_start_request'
KPAIR_COMPLETED_SUCCESS_RESPONSE = 'pair_completed_success_response'
KPAIR_COMPLETED_FAILURE_RESPONSE = 'pair_completed_failure_response'
KPAIR_TIMEOUT_SUCCESS_RESPONSE = 'pair_timeout_success_response'
KPAIR_TIMEOUT_FAILURE_RESPONSE = 'pair_timeout_failure_response'

KUNPAIR_ASK_REQUEST = 'unpair_ask_request'

KUPNP_ASK_REQUEST = 'upnp_ask_request'
KUPNP_SETTING_REQUEST = 'upnp_setting_request'

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
      
      when KUNPAIR_ASK_REQUEST
        msg = UNPAIR_ASK_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
        
      when KUPNP_ASK_REQUEST
        msg = UPNP_ASK_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
        
      when KUPNP_SETTING_REQUEST
        msg = UPNP_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:field_item], info[:session_id]]
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
    
    elsif msg.form.form? then
      title = msg.form.title
      puts 'Receive form message ' + title
      
      case title
        when 'upnp_service'
          session_id = msg.thread
          service_list = Array.new
          
          MultiXml.parser = :rexml
          xml = MultiXml.parse(msg.form.to_s)
          xml["x"]["item"].each do |item|
            service_name = nil
            status = nil
            enabled = nil
            description = nil
            
            item["field"].each do |field|
              var = field["var"]
              case var
                when 'service-name'
                  service_name = field["value"]
                when 'status'
                  status = field["value"] == 'true' ? true : false
                when 'enabled'
                  enabled = field["value"] == 'true' ? true : false
                when 'description'
                  description = field["value"]
              end
            end
            
            service = {:service_name => service_name,
                       :status => status,
                       :enabled => enabled,
                       :description => description
                      }
            service_list << service
          end
          
          service_list_json = JSON.generate(service_list)
          
          data = {id: session_id, status: 1, service_list: service_list_json}
          isSuccess = @db_conn.db_upnp_session_update(data)
          puts 'Update Upnp form to DB' if isSuccess
      end
    else
    end
    #write_to_stream msg.reply
  end
end