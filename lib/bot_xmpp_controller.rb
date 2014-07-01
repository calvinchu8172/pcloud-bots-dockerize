#!/usr/bin/env ruby

require_relative 'bot_db_access'
require_relative 'bot_route_access'
require_relative 'bot_pair_protocol_template'
require 'blather/client/dsl'
require 'multi_xml'
require 'json'
require 'yaml'
require 'rubygems'
require 'eventmachine'

BOT_ACCOUNT_CONFIG_FILE = '../config/bot_account_config.yml'

KPAIR_START_REQUEST = 'pair_start_request'
KPAIR_COMPLETED_SUCCESS_RESPONSE = 'pair_completed_success_response'
KPAIR_COMPLETED_FAILURE_RESPONSE = 'pair_completed_failure_response'
KPAIR_TIMEOUT_SUCCESS_RESPONSE = 'pair_timeout_success_response'
KPAIR_TIMEOUT_FAILURE_RESPONSE = 'pair_timeout_failure_response'

KUNPAIR_ASK_REQUEST = 'unpair_ask_request'

KUPNP_ASK_REQUEST = 'upnp_ask_request'
KUPNP_SETTING_REQUEST = 'upnp_setting_request'

KDDNS_SETTING_REQUEST = 'ddns_setting_request'
KDDNS_SETTING_SUCCESS_RESPONSE = 'ddns_setting_success_response'
KDDNS_SETTING_FAILURE_RESPONSE = 'ddns_setting_failure_response'

module XMPPController
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
    @route_conn = BotRouteAccess.new
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
        msg = PAIR_COMPLETED_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:email], info[:session_id]]
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
        
        unpairThread = Thread.new{
          xmpp_account = info[:xmpp_account]
          session_id = info[:session_id]
          
          msg = UNPAIR_ASK_REQUEST % [xmpp_account, @bot_xmpp_account, session_id]
          write_to_stream msg
          puts 'Send Unpair message to device - ' + info[:xmpp_account]
          
          df = EM::DefaultDeferrable.new
          periodic_timer = EM.add_periodic_timer(15) {
            unpair_session = @db_conn.db_unpair_session_access({id: session_id})
            if !unpair_session.nil? then
              write_to_stream msg
              puts 'Resend Unpair message to device - ' + info[:xmpp_account]
            else
              df.set_deferred_status :succeeded, "Unpair success, and remove timer - " + info[:xmpp_account]
            end
          }
          EM.add_timer(60 * 1){
            df.set_deferred_status :succeeded, "Unpair times is up - " + info[:xmpp_account]
          }
          df.callback do |x|
            unpair_session = @db_conn.db_unpair_session_access({id: session_id})
            
            if !unpair_session.nil? then
              @db_conn.db_unpair_session_delete(unpair_session.id)
            end
            
            EM.cancel_timer(periodic_timer)
            puts 'Unpair timeout, stop timer - ' + info[:xmpp_account]
          end
        }
        unpairThread.abort_on_exception = FALSE
        
      when KUPNP_ASK_REQUEST
        msg = UPNP_ASK_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
        
      when KUPNP_SETTING_REQUEST
        msg = UPNP_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:field_item], info[:session_id]]
        write_to_stream msg
        
      when KDDNS_SETTING_REQUEST
        domain_S = info[:full_domain].split('.')
        host_name = domain_S[0]
        domain_S.shift
        domain_name = domain_S.join('.')
        domain_name += '.' if '.' != domain_name[-1, 1]
        
        routeThread = Thread.new{
          puts 'Start send DDNS request to device'
          @db_conn.db_ddns_session_update({id: info[:session_id], status: 1})
          
          record_info = {host_name: host_name, domain_name: domain_name, ip: info[:ip]}
          isSuccess = @route_conn.create_record(record_info)
          
          if isSuccess then
            msg = DDNS_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, host_name, domain_name, info[:session_id]]
            write_to_stream msg
            puts 'Send DDNS request to ' + info[:xmpp_account]
            
            df = EM::DefaultDeferrable.new
            periodic_timer = EM.add_periodic_timer(15) {
              ddns_session = @db_conn.db_ddns_session_access({id: info[:session_id]})
              status = ddns_session.status
              if 2 != status then
                msg = DDNS_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, host_name, domain_name, info[:session_id]]
                write_to_stream msg
                puts 'Resent DDNS request to' + info[:xmpp_account]
              else
                df.set_deferred_status :succeeded, "Setup DDNS timeup"
              end
            }
            EM.add_timer(60 * 1){
              df.set_deferred_status :succeeded, "Setup DDNS timeup"
            }
            df.callback do |x|
              ddns_session = @db_conn.db_ddns_session_access({id: info[:session_id]})
              status = ddns_session.status
              if 1 == status then
                @db_conn.db_ddns_session_update({id: info[:session_id], status: 3})
              end
            
              EM.cancel_timer(periodic_timer)
              puts 'Setup DDNS timeout, stop timer - ' + info[:xmpp_account]
            end
          else
            @db_conn.db_ddns_session_update({id: info[:session_id], status: 3})
          end
        }
        routeThread.abort_on_exception = FALSE
        
      when KDDNS_SETTING_SUCCESS_RESPONSE
        msg = DDNS_SETTING_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
      
      when KDDNS_SETTING_FAILURE_RESPONSE
        msg = DDNS_SETTING_FAILURE_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
    end
  end
  
  #subscription :request? do |s|
  #  write_to_stream s.approve!
  #end
  
  message :normal? do |msg|
    begin
    
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
          isSuccess = FALSE
          session_id = msg.thread
          isSuccess = @db_conn.db_unpair_session_delete(session_id) if !session_id.nil?
          puts 'Delete unpair sesson success as unpair success' if isSuccess
        when 'upnp_service'
          session_id = msg.thread
          data = {id: session_id, status:4}
          isSuccess = @db_conn.db_upnp_session_update(data)
          puts 'Update upnp session setting success' if isSuccess
        when 'config' #for DDNS settings
          session_id = msg.thread
          data = {id: session_id, status:2}
          isSuccess = @db_conn.db_ddns_session_update(data)
          puts 'Update ddns session success'
          
          ddns_session = @db_conn.db_ddns_session_access({id: session_id})
          device = @db_conn.db_device_session_access({xmpp_account: msg.from.node})
          if !ddns_session.nil? && !device.nil? then
            data = {device_id: ddns_session.device_id,
                    ip_address: device.ip,
                    full_domain: ddns_session.full_domain
                   }
            isSuccess = @db_conn.db_ddns_insert(data)
            puts 'Insert new DDNS record ' + ddns_session.full_domain if !isSuccess.nil?
          end
          
          puts 'Receive ddns success response'
      end
        
    elsif msg.form.submit? then
      title = msg.form.title
      puts 'Receive submit message ' + title
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'completed' == action then
            device = @db_conn.db_pairing_session_access({id: session_id})
            expire_time = device[:expire_at]
            
            if expire_time > DateTime.now 
              data = {id: session_id, status: 2}
              isSuccess = @db_conn.db_pairing_session_update(data)
              puts 'Update pair session completed success' if isSuccess
              
              isSuccess = @db_conn.db_pairing_insert(device[:user_id], device[:device_id])
              puts 'Insert paired data success' if isSuccess
            
              user = @db_conn.db_user_access(device[:user_id])
              info = {xmpp_account: msg.from, session_id: session_id, email: user.nil? ? '' : user.email}
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
        when 'config' #for DDNS Setting
          host_name = nil
          domain_name = nil
          
          msg.form.fields.each do |field|
            host_name = field.value.downcase if 'hostname_prefix' == field.var
            domain_name = field.value.downcase if 'hostname_suffix' == field.var
          end
          
          regex = /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])(.)$/
          dns_valid = regex.match(host_name + '.' + domain_name)
          
          domain_name += '.' if '.' != domain_name[-1, 1]
          
          if !host_name.empty? && !domain_name.empty? && !dns_valid.nil? then
            device_ip = nil
            device_id = nil
            old_device_id = nil
            xmpp_account = msg.from.node
            device = @db_conn.db_device_session_access({xmpp_account: xmpp_account})
            device_ip = device.ip if !device.nil?
            device_id = device.device_id if !device.nil?
            
            ddns_record = @db_conn.db_ddns_access({full_domain: host_name + '.' + domain_name})
            old_device_id = ddns_record.device_id if !ddns_record.nil?
            
            if !device_id.nil? && old_device_id.nil? then
              routeThread = Thread.new{
                session_id = msg.thread
                record_info = {host_name: host_name, domain_name: domain_name, ip: device_ip}
                isSuccess = @route_conn.create_record(record_info)
                
                if isSuccess then
                  data = {device_id: device_id, ip_address: device_ip, full_domain: host_name + '.' + domain_name}
                  @db_conn.db_ddns_insert(data)
                  
                  info = {xmpp_account: msg.from, session_id: session_id}
                  send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
                  puts 'Response DDNS success to device - ' + msg.from.to_s
                else
                  info = info = {xmpp_account: msg.from, error_code: 997, session_id: session_id}
                  send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                  puts 'Response create dns record error to device - ' + msg.from.to_s
                end
              }
              routeThread.abort_on_exception = TRUE
            elsif !device_id.nil? && !old_device_id.nil? then
              if device_id == old_device_id then
                info = info = {xmpp_account: msg.from, error_code: 996, session_id: msg.thread}
                send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                puts 'Response dns record has been register to device - ' + msg.from.to_s
              else
                info = info = {xmpp_account: msg.from, error_code: 995, session_id: msg.thread}
                send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                puts 'Error, response dns record has been used to device - ' + msg.from.to_s
              end
            else
              info = info = {xmpp_account: msg.from, error_code: 998, session_id: msg.thread}
              send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
              puts 'Response device ip not find to device - ' + msg.from.to_s
            end
          else
            info = info = {xmpp_account: msg.from, error_code: 999, session_id: msg.thread}
            send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
            puts 'Response DDNS format error to device - ' + msg.from.to_s
          end
          
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
          isSuccess = FALSE
          session_id = msg.thread
          isSuccess = @db_conn.db_unpair_session_delete(session_id) if !session_id.nil?
          puts 'Delete unpair sesson success as unpair failure' if isSuccess
          
        when 'upnp_service'
          session_id = msg.thread
          data = {id: session_id, status: 3}
          isSuccess = @db_conn.db_upnp_session_update(data)
          puts 'Update upnp session failue success' if isSuccess
        when 'config' #for DDNS Setting
          session_id = msg.thread
          data = {id: session_id, status:3}
          isSuccess = @db_conn.db_ddns_session_update(data)
          
          puts 'Update / create DDNS record failure' if isSuccess
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
    rescue Exception => error
      puts 'ERROR : ' + error.to_s
    end
  end
end