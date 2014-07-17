#!/usr/bin/env ruby

require_relative 'bot_db_access'
require_relative 'bot_route_access'
require_relative 'bot_pair_protocol_template'
require_relative 'bot_mail_access'
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
    
    @db_conn = BotDBAccess.new
    @route_conn = BotRouteAccess.new
    @mail_conn = BotMailAccess.new
  end
  
  def self.run
    EM.run { client.run }
  end
  
  def self.container(data)
    yield(data)
  end
  
  def self.retry_ddns_register
    ddnss = @db_conn.db_retrive_retry_ddns
    ddnss.each do |ddns|
      session_id = ddns.id
      device_id = ddns.device_id
      full_domain = ddns.full_domain

      device = @db_conn.db_device_session_access({device_id: device_id})
      ip = device.ip
      xmpp_account = device.xmpp_account

      user_email = @db_conn.db_retrive_user_email_by_xmpp_account(xmpp_account)

      domain_S = full_domain.split('.')
      host_name = domain_S[0]
      domain_S.shift
      domain_name = domain_S.join('.')
      domain_name += '.' if '.' != domain_name[-1, 1]

      route_data = {host_name: host_name, domain_name: domain_name, ip: ip}
      isSuccess = @route_conn.create_record(route_data)
      puts '[%s] Retry register DDNS success - %s' % [DateTime.now, full_domain] if isSuccess
      
      if isSuccess then
        isSuccess = @mail_conn.send_online_mail(user_email)
        puts '[%s] Send online mail to user - %s' % [DateTime.now, user_email] if isSuccess
        
        isSuccess = @db_conn.db_ddns_retry_session_delete(session_id)
        puts '[%s] Delete DDNS retry session:%d' % [DateTime.now, session_id] if isSuccess
      end
    end
  end
  
  def self.send_request(job, info)
    
    case job
      when KPAIR_START_REQUEST
        msg = PAIR_START_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KPAIR_START_REQUEST, info[:xmpp_account]]
      
      when KPAIR_COMPLETED_SUCCESS_RESPONSE
        msg = PAIR_COMPLETED_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:email], info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KPAIR_COMPLETED_SUCCESS_RESPONSE, info[:xmpp_account]]
      
      when KPAIR_COMPLETED_FAILURE_RESPONSE
        msg = PAIR_COMPLETED_FAILURE_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KPAIR_COMPLETED_FAILURE_RESPONSE, info[:xmpp_account]]
        
      when KPAIR_TIMEOUT_SUCCESS_RESPONSE
        msg = PAIR_TIMEOUT_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KPAIR_TIMEOUT_SUCCESS_RESPONSE, info[:xmpp_account]]
      
      when KPAIR_TIMEOUT_FAILURE_RESPONSE
        msg = PAIR_TIMEOUT_FAILURE_FAILURE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KPAIR_TIMEOUT_FAILURE_RESPONSE, info[:xmpp_account]]
      
      when KUNPAIR_ASK_REQUEST
        
        unpairThread = Thread.new{
          xmpp_account = info[:xmpp_account]
          session_id = info[:session_id]
          
          domain_S = info[:full_domain].split('.')
          host_name = domain_S[0]
          domain_S.shift
          domain_name = domain_S.join('.')
          domain_name += '.' if '.' != domain_name[-1, 1]
          
          isSuccess = @route_conn.delete_record({host_name: host_name, domain_name: domain_name})
          break if !isSuccess
          
          isSuccess = FALSE
          ddns = @db_conn.db_ddns_access({full_domain: info[:full_domain]})
          isSuccess = @db_conn.db_ddns_delete(ddns.id) if !ddns.nil?
          
          msg = UNPAIR_ASK_REQUEST % [xmpp_account, @bot_xmpp_account, session_id]
          write_to_stream msg
          puts '[%s] Send %s message to device - %s' % [DateTime.now, KUNPAIR_ASK_REQUEST, info[:xmpp_account]]
          
          df = EM::DefaultDeferrable.new
          periodic_timer = EM.add_periodic_timer(15) {
            unpair_session = @db_conn.db_unpair_session_access({id: session_id})
            if !unpair_session.nil? then
              write_to_stream msg
              puts '[%s] Resend Unpair message to device - %s' % [DateTime.now, info[:xmpp_account]]
            else
              df.set_deferred_status :succeeded, "[%s] Unpair success, and remove timer - %s" % [DateTime.now, info[:xmpp_account]]
            end
          }
          EM.add_timer(60 * 1){
            df.set_deferred_status :succeeded, "[%s] Unpair times is up - %s" % [DateTime.now, info[:xmpp_account]]
          }
          df.callback do |x|
            unpair_session = @db_conn.db_unpair_session_access({id: session_id})
            
            if !unpair_session.nil? then
              @db_conn.db_unpair_session_delete(unpair_session.id)
            end
            
            EM.cancel_timer(periodic_timer)
            puts '[%s] Unpair timeout, stop timer - %s' % [DateTime.now, info[:xmpp_account]]
          end
        }
        unpairThread.abort_on_exception = FALSE
        
      when KUPNP_ASK_REQUEST
        msg = UPNP_ASK_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:language], info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KUPNP_ASK_REQUEST, info[:xmpp_account]]
        
      when KUPNP_SETTING_REQUEST
        msg = UPNP_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, info[:language], info[:field_item], info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KUPNP_SETTING_REQUEST, info[:xmpp_account]]
        
      when KDDNS_SETTING_REQUEST
        domain_S = info[:full_domain].split('.')
        host_name = domain_S[0]
        domain_S.shift
        domain_name = domain_S.join('.')
        domain_name += '.' if '.' != domain_name[-1, 1]
        
        routeThread = Thread.new{
          puts '[%s] Start send DDNS request to device' % DateTime.now
          @db_conn.db_ddns_session_update({id: info[:session_id], status: 1})
          
          record_info = {host_name: host_name, domain_name: domain_name, ip: info[:ip]}
          isSuccess = @route_conn.create_record(record_info)
          
          if isSuccess then
            msg = DDNS_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, host_name, domain_name, info[:session_id]]
            write_to_stream msg
            puts '[%s] Send DDNS request to %s' % [DateTime.now, info[:xmpp_account]]
            
            ddns_retry_session = @db_conn.db_ddns_retry_session_access({full_domain: info[:full_domain]})
            @db_conn.db_ddns_retry_session_delete(ddns_retry_session.id) if !ddns_retry_session.nil?

            df = EM::DefaultDeferrable.new
            periodic_timer = EM.add_periodic_timer(15) {
              ddns_session = @db_conn.db_ddns_session_access({id: info[:session_id]})
              status = ddns_session.status
              if 2 != status then
                msg = DDNS_SETTING_REQUEST % [info[:xmpp_account], @bot_xmpp_account, host_name, domain_name, info[:session_id]]
                write_to_stream msg
                puts '[%s] Resent DDNS request to %s' % [DateTime.now, info[:xmpp_account]]
              else
                df.set_deferred_status :succeeded, "[%s] Setup DDNS timeup" % DateTime.now
              end
            }
            EM.add_timer(60 * 1){
              df.set_deferred_status :succeeded, "[%s] Setup DDNS timeup" % DateTime.now
            }
            df.callback do |x|
              ddns_session = @db_conn.db_ddns_session_access({id: info[:session_id]})
              status = ddns_session.status
              if 1 == status then
                @db_conn.db_ddns_session_update({id: info[:session_id], status: 3})
              end
            
              EM.cancel_timer(periodic_timer)
              puts '[%s] Setup DDNS timeout, stop timer - %s' % [DateTime.now, info[:xmpp_account]]
            end
          else
            @db_conn.db_ddns_session_update({id: info[:session_id], status: 3})
            user_email = @db_conn.db_retrive_user_email_by_ddns_session_id(info[:session_id])

            ddns_session = @db_conn.db_ddns_session_access({id: info[:session_id]})

            @db_conn.db_ddns_retry_session_insert({device_id: ddns_session.device_id, full_domain: ddns_session.full_domain})
            isSuccess = @mail_conn.send_offline_mail(user_email) if !user_email.nil?
            puts '[%s] Send DDNS offline email to user - %s' % [DateTime.now, user_email] if isSuccess
          end
        }
        routeThread.abort_on_exception = FALSE
        
      when KDDNS_SETTING_SUCCESS_RESPONSE
        msg = DDNS_SETTING_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KDDNS_SETTING_SUCCESS_RESPONSE, info[:xmpp_account]]
      
      when KDDNS_SETTING_FAILURE_RESPONSE
        msg = DDNS_SETTING_FAILURE_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
        puts '[%s] Send %s message to device - %s' % [DateTime.now, KDDNS_SETTING_FAILURE_RESPONSE, info[:xmpp_account]]
    end
  end
  
  #subscription :request? do |s|
  #  write_to_stream s.approve!
  #end
  disconnected {
    sleep(10)
    puts '[%s] Reconnect - %s' % [DateTime.now, client.jid.to_s]
    begin
      self.run
    rescue Exception => error
      puts error
    end
    }
  
  message :normal? do |msg|
    begin
    
    if msg.form.result? then
      title = msg.form.title
      puts '[%s] Receive result message %s' % [DateTime.now, title]
      
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'start' == action then
            data = {id: session_id, status: 1}
            isSuccess = @db_conn.db_pairing_session_update(data)
            puts '[%s] Update the status of pair session:%d to "WAIT" success as received "START PAIR" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
          end
        when 'unpair'
          isSuccess = FALSE
          session_id = msg.thread
          isSuccess = @db_conn.db_unpair_session_delete(session_id) if !session_id.nil?
          puts '[%s] Delete unpair sesson:%d success as received "UNPAIR SUCCESS" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
        when 'upnp_service'
          session_id = msg.thread
          data = {id: session_id, status:4}
          isSuccess = @db_conn.db_upnp_session_update(data)
          puts '[%s] Update upnp session:%d success as received "UPNP SET SUCCESS" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
        when 'config' #for DDNS settings
          session_id = msg.thread
          data = {id: session_id, status:2}
          isSuccess = @db_conn.db_ddns_session_update(data)
          puts '[%s] Update ddns session:%d success as received "DDNS UPDATE SUCCESS" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
          
          ddns_session = @db_conn.db_ddns_session_access({id: session_id})
          device = @db_conn.db_device_session_access({xmpp_account: msg.from.node})
          if !ddns_session.nil? && !device.nil? then
            data = {device_id: ddns_session.device_id,
                    ip_address: device.ip,
                    full_domain: ddns_session.full_domain
                   }
            isSuccess = @db_conn.db_ddns_insert(data)
            puts '[%s] Insert new DNS record - %s into DB' % [DateTime.now, ddns_session.full_domain] if !isSuccess.nil?
          end
      end
        
    elsif msg.form.submit? then
      title = msg.form.title
      puts '[%s] Receive submit message %s' % [DateTime.now, title]
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'completed' == action then
            device = @db_conn.db_pairing_session_access({id: session_id})
            expire_time = device[:expire_at] if !device.nil?
            
            if !device.nil? then
              if expire_time > DateTime.now 
                data = {id: session_id, status: 2}
                isSuccess = @db_conn.db_pairing_session_update(data)
                puts '[%s] Update pair session:%d completed success received from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
                
                isSuccess = @db_conn.db_pairing_insert(device[:user_id], device[:device_id])
                puts '[%s] Insert paired data - user:%d, device:%d success' % [DateTime.now, device[:user_id], device[:device_id]] if isSuccess
            
                user = @db_conn.db_user_access(device[:user_id])
                info = {xmpp_account: msg.from, session_id: session_id, email: user.nil? ? '' : user.email}
                send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
                puts '[%s] Response pair completed success to device - %s' % [DateTime.now, msg.from.to_s]
              else
                data = {id: session_id, status: 4}
                isSuccess = @db_conn.db_pairing_session_update(data)
                puts '[%s] Update pair session:%d time out' % [DateTime.now, session_id] if isSuccess
            
                info = {xmpp_account: msg.from, error_code: 899, session_id: session_id}
                send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
                puts '[%s] Response pair completed time out to device - %s' % [DateTime.now, msg.from.to_s]
              end
            else
              info = {xmpp_account: msg.from, error_code: 898, session_id: session_id}
              send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
              puts '[%s] Response completed pair session id unfound received from - %s' % [DateTime.now, msg.from.to_s]
            end
          end
          
          if 'cancel' == action then # for timeout request
            pair_session = @db_conn.db_pairing_session_access({id: session_id})
            
            if !pair_session.nil? then
              data = {id: session_id, status: 4}
              isSuccess = @db_conn.db_pairing_session_update(data)
              puts '[%s] Update pair session:%d time out request from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
            
              if isSuccess
                info = {xmpp_account: msg.from, session_id: session_id}
                send_request(KPAIR_TIMEOUT_SUCCESS_RESPONSE, info)
                puts '[%s] Response received time out success to device - %s' % [DateTime.now, msg.from.to_s]
              else
                info = {xmpp_account: msg.from, error_code: 897, session_id: session_id}
                send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
                puts '[%s] Response received time out failure to device - %s' % [DateTime.now, msg.from.to_s]
              end
            else
              info = {xmpp_account: msg.from, error_code: 898, session_id: session_id}
              send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
              puts '[%s] Response cancel pair session id unfound received from - %s' % [DateTime.now, msg.from.to_s]
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
              data = {host_name: host_name,
                      domain_name: domain_name,
                      device_ip: device_ip,
                      device_id: device_id,
                      session_id: msg.thread,
                      msg_from: msg.from.to_s,
                      xmpp_account: msg.from.node
                      }
              # Use container for provied variable over write
              container(data){
                |x|
                
                routeThread = Thread.new{
                  session_id = x[:session_id]
                  record_info = {host_name: x[:host_name], domain_name: x[:domain_name], ip: x[:device_ip]}
                  isSuccess = @route_conn.create_record(record_info)
                
                  if isSuccess then
                    record = {device_id: x[:device_id], ip_address: x[:device_ip], full_domain: x[:host_name] + '.' + x[:domain_name]}
                    @db_conn.db_ddns_insert(record)

                    ddns_retry_session = @db_conn.db_ddns_retry_session_access({full_domain: x[:host_name] + '.' + x[:domain_name]})
                    @db_conn.db_ddns_retry_session_delete(ddns_retry_session.id) if !ddns_retry_session.nil?

                    info = {xmpp_account: x[:msg_from], session_id: session_id}
                    send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
                    puts '[%s] Response DDNS success to device - %s' % [DateTime.now, x[:msg_from]]
                  else
                    info = info = {xmpp_account: x[:msg_from], error_code: 997, session_id: session_id}
                    send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                    puts '[%s] Response create dns record error to device - %s' % [DateTime.now, x[:msg_from]]

                    @db_conn.db_ddns_retry_session_insert({device_id: x[:device_id], full_domain: x[:host_name] + '.' + x[:domain_name]})

                    user_email = @db_conn.db_retrive_user_email_by_xmpp_account(x[:xmpp_account])
                    isSuccess = @mail_conn.send_offline_mail(user_email) if !user_email.nil?
                    puts '[%s] Send DDNS offline email to user - %s' % [DateTime.now, user_email] if isSuccess
                  end
                }
                routeThread.abort_on_exception = TRUE
              }
              
            elsif !device_id.nil? && !old_device_id.nil? then
              if device_id == old_device_id then
                info = info = {xmpp_account: msg.from, session_id: msg.thread}
                send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
                puts '[%s] Response dns record has been register to device - %s' % [DateTime.now, msg.from.to_s]
              else
                info = info = {xmpp_account: msg.from, error_code: 995, session_id: msg.thread}
                send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                puts '[%s] Error, response dns record has been used to device - %s' % [DateTime.now, msg.from.to_s]
              end
            else
              info = info = {xmpp_account: msg.from, error_code: 998, session_id: msg.thread}
              send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
              puts '[%s] Response device ip not find to device - %s' % [DateTime.now, msg.from.to_s]
            end
          else
            info = info = {xmpp_account: msg.from, error_code: 999, session_id: msg.thread}
            send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
            puts '[%s] Response DDNS format error to device - %s' % [DateTime.now, msg.from.to_s]
          end 
      end
      
    elsif msg.form.cancel? then
      title = msg.form.title
      puts '[%s] Receive cancel message %s' % [DateTime.now, title]
      
      case title
        when 'pair'
          action = msg.form.field('action').value
          session_id = msg.thread
            
          if 'start' == action then
            data = {id: session_id, status: 4}
            isSuccess = @db_conn.db_pairing_session_update(data)
            puts '[%s] Update the status of pair session:%d to "FAILURE" success as received "START PAIR FAILURE" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
          end
        when 'unpair'
          isSuccess = FALSE
          session_id = msg.thread
          isSuccess = @db_conn.db_unpair_session_delete(session_id) if !session_id.nil?
          puts '[%s] Delete unpair sesson:%d success as received "UNPAIR FAILURE" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
        when 'upnp_service'
          session_id = msg.thread
          data = {id: session_id, status: 3}
          isSuccess = @db_conn.db_upnp_session_update(data)
          puts '[%s] Update the status of upnp session:%d to "FAILURE" success as received "UPNP SET FAILURE" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
        when 'config' #for DDNS Setting
          session_id = msg.thread
          data = {id: session_id, status:3}
          isSuccess = @db_conn.db_ddns_session_update(data)
          puts '[%s] Update the status of ddns session:%d to "FAILURE" success as received "DDNS UPDATE FAILURE" response from device - %s' % [DateTime.now, session_id, msg.from.to_s] if isSuccess
      end
    
    elsif msg.form.form? then
      title = msg.form.title
      puts '[%s] Receive form message %s' % [DateTime.now, title]
      
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
          puts '[%s] Update Upnp form to upnp session:%d' % [DateTime.now, session_id] if isSuccess
      end
    else
    end
    rescue Exception => error
      puts '[%s] ERROR : %s' % [DateTime.now, error.to_s]
    end
  end
end
