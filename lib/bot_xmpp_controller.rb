#!/usr/bin/env ruby

require_relative 'bot_db_access'
require_relative 'bot_route_access'
require_relative 'bot_redis_access'
require_relative 'bot_pair_protocol_template'
require_relative 'bot_mail_access'
require_relative 'bot_unit'
require 'fluent-logger'
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

KSTATUS_START = 'start'
KSTATUS_WAITING = 'waiting'
KSTATUS_CANCEL = 'cancel'
KSTATUS_TIMEOUT = 'timeout'
KSTATUS_FAILURE = 'failure'
KSTATUS_DONE = 'done'
KSTATUS_OFFLINE = 'offline'
KSTATUS_FORM = 'form'
KSTATUS_SUBMIT = 'submit'
KSTATUS_UPDATED = 'updated'
KSTATUS_SUCCESS = 'success'

module XMPPController
  extend Blather::DSL
  
  def self.new(account, password)
    @db_conn = nil
    @bot_xmpp_account = account
    @bot_xmpp_password = password
    
    setup @bot_xmpp_account, @bot_xmpp_password
    
    @db_conn = BotDBAccess.new
    @rd_conn = BotRedisAccess.new
    @route_conn = BotRouteAccess.new
    @mail_conn = BotMailAccess.new
    
    @xmpp_server_domain = '@%s' % client.jid.domain
    @xmpp_resource_id = '/device'
    
    Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)
  end
  
  def self.run
    EM.run {
      Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                               direction: 'N/A',
                                               to: 'N/A',
                                               form: 'N/A',
                                               id: 'N/A',
                                               full_domain: 'N/A',
                                               message:"Start re-update DDNS record ...",
                                               data: 'N/A'})
      EM.add_periodic_timer(0.3) {
        retry_ddns_register
      }
        
      client.run
      }
  end
  
  def self.container(data)
    yield(data)
  end
  
  def self.alive
    return TRUE
  end

  def self.retry_ddns_register
    count = @rd_conn.rd_ddns_batch_session_count
    return nil if 0 == count
    
    isLock = @rd_conn.rd_ddns_batch_lock_isSet
    return nil if isLock
    
    #begin
      @rd_conn.rd_ddns_batch_lock_set
      result = @rd_conn.rd_ddns_batch_session_access
      temp = Array.new
      i = 0
      while i < 100 do
        temp << result[i]
        i+=1
      end
      
      ddnss = temp.reverse
      
      zones_list = @route_conn.zones_list
      zones_list.each do |zone|
        zone_name = zone["name"]
      
        records = Array.new
        tempR = Array.new
        ddnss.each do |data|
          if valid_json? data then
            ddns = JSON.parse(data)
        
            session_id = ddns["index"]
            device_id = ddns["device_id"]
            full_domain = ddns["full_domain"]
            domain_name = find_domainname(full_domain)
            action = ddns["action"]
      
            device = @rd_conn.rd_device_session_access(device_id)
            ip = device["ip"]
            
            isInclouded = tempR.include?(full_domain)
            if zone_name == domain_name && !isInclouded then
              records << {full_domain: full_domain, ip: ip, action: action, index: session_id}
              tempR << full_domain
            end
          end
        end
      
        if records.count > 0 then
          Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                                   direction: 'N/A',
                                                   to: 'N/A',
                                                   form: 'N/A',
                                                   id: 'N/A',
                                                   full_domain: 'N/A',
                                                   message:"Batch register DDNS record ...",
                                                   data: 'N/A'})
        
          isSuccess = @route_conn.batch_create_records({domain_name: zone_name, records: records})
          
          #if update records failure, remove delete action and do again.
          if !isSuccess then
            i = 0
            while i < records.count do
              action = records[i][:action]
              records.delete_at(i) if 'delete' == action
              i+=1
            end
            sleep(0.3)
            
            isSuccess = @route_conn.batch_create_records({domain_name: zone_name, records: records})
          end
        
          ddnss.each do |data|
            if valid_json? data then
              ddns = JSON.parse(data)
          
              session_id = ddns["index"]
              device_id = ddns["device_id"]
              full_domain = ddns["full_domain"]
              hasMailed = ddns["hasMailed"]
              action = ddns["action"]

              device = @rd_conn.rd_device_session_access(device_id)
              ip = device["ip"]

              user_email = @db_conn.db_retrive_user_email_by_device_id(device_id)
          
              Fluent::Logger.post(isSuccess ? FLUENT_BOT_SYSINFO : FLUENT_BOT_SYSERROR,
                                    {event: 'DDNS',
                                     direction: 'N/A',
                                     to: 'N/A',
                                     form: 'N/A',
                                     id: session_id,
                                     full_domain: full_domain,
                                     message:"Batch register DDNS record %s" % [isSuccess ? 'success' : 'failure'] ,
                                     data: {ip: ip}})
          
              if isSuccess then
                if hasMailed && 'update' == action then
                  isSuccess = @mail_conn.send_online_mail(user_email)
                  Fluent::Logger.post(isSuccess ? FLUENT_BOT_SYSINFO : FLUENT_BOT_SYSERROR,
                                      {event: 'DDNS',
                                       direction: 'N/A',
                                       to: 'N/A',
                                       form: 'N/A',
                                       id: session_id,
                                       full_domain: 'N/A',
                                       message:"Send online mail to user %s" % [isSuccess ? 'success' : 'failure'] ,
                                       data: {user_email: user_email}})
                end
                ddns_session = @rd_conn.rd_ddns_session_access(session_id)
                @rd_conn.rd_ddns_session_update({index: session_id, status: KSTATUS_SUCCESS}) if !ddns_session.nil?
                
                isSuccess = @rd_conn.rd_ddns_batch_session_delete(data)
                Fluent::Logger.post(isSuccess ? FLUENT_BOT_SYSINFO : FLUENT_BOT_SYSERROR,
                                    {event: 'DDNS',
                                     direction: 'N/A',
                                     to: 'N/A',
                                     form: 'N/A',
                                     id: session_id,
                                     full_domain: 'N/A',
                                     message:"Delete DDNS batch session %s" % [isSuccess ? 'success' : 'failure'] ,
                                     data: 'N/A'})
              else
                if !hasMailed && 'update' == action then
                  isSuccess = @mail_conn.send_offline_mail(user_email)
                  Fluent::Logger.post(isSuccess ? FLUENT_BOT_SYSINFO : FLUENT_BOT_SYSERROR,
                                      {event: 'DDNS',
                                       direction: 'N/A',
                                       to: 'N/A',
                                       form: 'N/A',
                                       id: session_id,
                                       full_domain: 'N/A',
                                       message:"Send offline mail to user %s" % [isSuccess ? 'success' : 'failure'] ,
                                       data: {user_email: user_email}})
                  
                  ddns_session = @rd_conn.rd_ddns_session_access(session_id)
                  @rd_conn.rd_ddns_session_update({index: session_id, status: KSTATUS_FAILURE}) if !ddns_session.nil?
                  
                  @rd_conn.rd_ddns_batch_session_delete(data)
                  retry_data = {index: session_id, device_id: device_id, full_domain: full_domain, action: 'update', hasMailed: true}
                  @rd_conn.rd_ddns_batch_session_insert(JSON.generate(retry_data), session_id)
                end
              end
            end
          end    
        end
      
        sleep(0.2)
      end
      @rd_conn.rd_ddns_batch_lock_delete
    #rescue
      @rd_conn.rd_ddns_batch_lock_delete
    #end
  end
  
  def self.send_request(job, info)
    
    case job
      when KPAIR_START_REQUEST
        device_xmpp_account = info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id
        device_id = info[:device_id]
        msg = PAIR_START_REQUEST % [device_xmpp_account, @bot_xmpp_account, device_id]
        write_to_stream msg
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'PAIR',
                                                  direction: 'Bot->Device',
                                                  to: device_xmpp_account,
                                                  form: @bot_xmpp_account,
                                                  id: device_id,
                                                  full_domain: 'N/A',
                                                  message:"Send PAIR START REQUEST message to device" ,
                                                  data: 'N/A'})
      
      when KPAIR_COMPLETED_SUCCESS_RESPONSE
        msg = PAIR_COMPLETED_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:email], info[:session_id]]
        write_to_stream msg
      
      when KPAIR_COMPLETED_FAILURE_RESPONSE
        msg = PAIR_COMPLETED_FAILURE_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
        
      when KPAIR_TIMEOUT_SUCCESS_RESPONSE
        msg = PAIR_TIMEOUT_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
      
      when KPAIR_TIMEOUT_FAILURE_RESPONSE
        msg = PAIR_TIMEOUT_FAILURE_FAILURE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
      
      when KUNPAIR_ASK_REQUEST
        
        EM.defer {
          xmpp_account = info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id
          session_id = info[:session_id]
          
          if !info[:full_domain].nil?
            domain_S = info[:full_domain].split('.')
            host_name = domain_S[0]
            domain_S.shift
            domain_name = domain_S.join('.')
            domain_name += '.' if '.' != domain_name[-1, 1]
          
            isSuccess = @route_conn.delete_record({host_name: host_name, domain_name: domain_name})
            Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWERROR,
                                  {event: 'UNPAIR',
                                   direction: 'N/A',
                                   to: 'N/A',
                                   from: 'N/A',
                                   id: 'N/A',
                                   full_domain: host_name + '.' + domain_name,
                                   message:"Delete Route53 DDNS record %s as unpair" % [isSuccess ? 'success' : 'failure'] ,
                                   data: 'N/A'})
          
            isSuccess = FALSE
            ddns = @db_conn.db_ddns_access({full_domain: info[:full_domain]})
            isSuccess = @db_conn.db_ddns_delete(ddns.id) if !ddns.nil?
            Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                  {event: 'UNPAIR',
                                   direction: 'N/A',
                                   to: 'N/A',
                                   from: 'N/A',
                                   id: !ddns.nil? ? ddns.id : 'N/A',
                                   full_domain: host_name + '.' + domain_name,
                                   message:"Delete DB DDNS record as unpair %s" % [isSuccess ? 'success' : 'failure'] ,
                                   data: 'N/A'})
          end
          
          msg = UNPAIR_ASK_REQUEST % [xmpp_account, @bot_xmpp_account, session_id]
          write_to_stream msg
          Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UNPAIR',
                                                    direction: 'Bot->Device',
                                                    to: xmpp_account,
                                                    from: @bot_xmpp_account,
                                                    id: session_id,
                                                    full_domain: 'N/A',
                                                    message:"Send UNPAIR ASK REQUEST message to device" ,
                                                    data: 'N/A'})
          
          df = EM::DefaultDeferrable.new
          periodic_timer = EM.add_periodic_timer(15) {
            unpair_session = @rd_conn.rd_unpair_session_access(session_id)
            if !unpair_session.nil? then
              write_to_stream msg
              Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UNPAIR',
                                                        direction: 'Bot->Device',
                                                        to: xmpp_account,
                                                        from: @bot_xmpp_account,
                                                        id: session_id,
                                                        full_domain: 'N/A',
                                                        message:"Resend UNPAIR ASK REQUEST message to device" ,
                                                        data: 'N/A'})
            else
              df.set_deferred_status :succeeded, "[%s] Unpair success, and remove timer - %s" % [DateTime.now, info[:xmpp_account]]
            end
          }
          EM.add_timer(60 * 1){
            df.set_deferred_status :succeeded, "[%s] Unpair times is up - %s" % [DateTime.now, info[:xmpp_account]]
          }
          df.callback do |x|
            unpair_session = @rd_conn.rd_unpair_session_access(session_id)
            
            if !unpair_session.nil? then
              @rd_conn.rd_unpair_session_delete(session_id)
            end
            
            EM.cancel_timer(periodic_timer)
            Fluent::Logger.post(FLUENT_BOT_FLOWERROR, {event: 'UNPAIR',
                                                      direction: 'N/A',
                                                      to: 'N/A',
                                                      from: 'N/A',
                                                      id: session_id,
                                                      full_domain: 'N/A',
                                                      message:"Unpair timeout, stop resend message to device" ,
                                                      data: 'N/A'})
          end
        }
        #unpairThread.abort_on_exception = FALSE
        
      when KUPNP_ASK_REQUEST
        msg = UPNP_ASK_REQUEST % [info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id, @bot_xmpp_account, info[:language], info[:session_id]]
        write_to_stream msg
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                  direction: 'Bot->Device',
                                                  to: info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id,
                                                  from: @bot_xmpp_account,
                                                  id: info[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Send UPNP ASK REQUEST message to device" ,
                                                  data: {language: info[:language]}})
        
      when KUPNP_SETTING_REQUEST
        msg = UPNP_SETTING_REQUEST % [info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id, @bot_xmpp_account, info[:language], info[:field_item], info[:session_id]]
        write_to_stream msg
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                  direction: 'Bot->Device',
                                                  to: info[:xmpp_account],
                                                  from: @bot_xmpp_account,
                                                  id: info[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Send UPNP SETTING RESPONSE message to device" ,
                                                  data: {language: info[:language], field_item: info[:field_item]}})
        
      when KDDNS_SETTING_REQUEST
        EM.defer {
          host_name = find_hostname(info[:full_domain])
          domain_name = find_domainname(info[:full_domain])
        
          @rd_conn.rd_ddns_session_update({index: info[:session_id], status: KSTATUS_WAITING})
          Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'DDNS',
                                                    direction: 'N/A',
                                                    to: info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id,
                                                    from: @bot_xmpp_account,
                                                    id: info[:session_id],
                                                    full_domain: info[:full_domain],
                                                    message:"Prepare send DDNS SETTING REQUEST to device" ,
                                                    data: 'N/A'})
          
          ddns_record = @db_conn.db_ddns_access({device_id: info[:device_id].to_i})
          
          batch_data = {index: info[:session_id], device_id: info[:device_id], full_domain: info[:full_domain], action: 'update', hasMailed: false}
          @rd_conn.rd_ddns_batch_session_insert(JSON.generate(batch_data), info[:session_id])
          
          isSuccess = FALSE
          i = 0
          while !isSuccess && i < 100
            result = @rd_conn.rd_ddns_session_access(info[:session_id])
            isSuccess = KSTATUS_SUCCESS == result["status"] ? TRUE : FALSE
            i+=1
            sleep(0.1)
          end

          if !ddns_record.nil? && isSuccess then
            old_full_domain = ddns_record.full_domain.to_s

            data = {id: ddns_record.id, full_domain: info[:full_domain], ip_address: info[:ip]}
            isSuccess =  @db_conn.db_ddns_update(data)
            Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                  {event: 'DDNS',
                                   direction: 'N/A',
                                   to: 'N/A',
                                   from: 'N/A',
                                   id: ddns_record.id,
                                   full_domain: info[:full_domain],
                                   message:"Update DB DDNS setting %s" % [isSuccess ? 'success' : 'failure'] ,
                                   data: {ip: info[:ip]}})
            
            if old_full_domain != info[:full_domain]
              index = @rd_conn.rd_ddns_session_index_get
              batch_data = {index: index, device_id: info[:device_id], full_domain: old_full_domain, action: 'delete', hasMailed: false}
              isSuccess = @rd_conn.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
              Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWERROR,
                                    {event: 'DDNS',
                                     direction: 'N/A',
                                     to: 'N/A',
                                     from: 'N/A',
                                     id: 'N/A',
                                     full_domain: old_full_domain,
                                     message:"Delete previous DDNS setting in Route53 %s" % [isSuccess ? 'success' : 'failure'] ,
                                     data: 'N/A'})
            end
          else
            data = {device_id: info[:device_id], ip_address: info[:ip], full_domain: info[:full_domain]}
            new_ddns = @db_conn.db_ddns_insert(data)
            isSuccess = !new_ddns.nil? ? TRUE : FALSE
            Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                  {event: 'DDNS',
                                   direction: 'N/A',
                                   to: 'N/A',
                                   from: 'N/A',
                                   id: 'N/A',
                                   full_domain: info[:full_domain],
                                   message:"Insert new DDNS setting into DB %s" % [isSuccess ? 'success' : 'failure'] ,
                                   data: {device_id: info[:device_id], ip: info[:ip]}})
          end

          if isSuccess then
            msg = DDNS_SETTING_REQUEST % [info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id, @bot_xmpp_account, host_name, domain_name, info[:session_id]]
            write_to_stream msg
            Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'DDNS',
                                                      direction: 'Bot->Device',
                                                      to: info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id,
                                                      from: @bot_xmpp_account,
                                                      id: info[:session_id],
                                                      full_domain: host_name + '.' + domain_name,
                                                      message:"Send DDNS SETTING REQUEST to device" ,
                                                      data: 'N/A'})

            df = EM::DefaultDeferrable.new
            periodic_timer = EM.add_periodic_timer(15) {
              ddns_session = @rd_conn.rd_ddns_session_access(info[:session_id])
              status = ddns_session["status"]
              if KSTATUS_SUCCESS != status then
                msg = DDNS_SETTING_REQUEST % [info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id, @bot_xmpp_account, host_name, domain_name, info[:session_id]]
                write_to_stream msg
                Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'DDNS',
                                                          direction: 'Bot->Device',
                                                          to: info[:xmpp_account] + @xmpp_server_domain + @xmpp_resource_id,
                                                          from: @bot_xmpp_account,
                                                          id: info[:session_id],
                                                          full_domain: host_name + '.' + domain_name,
                                                          message:"Resend DDNS SETTING REQUEST to device" ,
                                                          data: 'N/A'})
              else
                df.set_deferred_status :succeeded, "[%s] Setup DDNS timeup" % DateTime.now
              end
            }
            EM.add_timer(60 * 1){
              df.set_deferred_status :succeeded, "[%s] Setup DDNS timeup" % DateTime.now
            }
            df.callback do |x|
              ddns_session = @rd_conn.rd_ddns_session_access(info[:session_id])
              status = ddns_session["status"]
              if KSTATUS_WAITING == status then
                @rd_conn.rd_ddns_session_update({index: info[:session_id], status: KSTATUS_SUCCESS})
              end
            
              EM.cancel_timer(periodic_timer)
              Fluent::Logger.post(FLUENT_BOT_FLOWERROR, {event: 'DDNS',
                                                        direction: 'N/A',
                                                        to: 'N/A',
                                                        from: 'N/A',
                                                        id: info[:session_id],
                                                        full_domain: 'N/A',
                                                        message:"Timeout, stop resend DDNS SETTING REQUEST message to device" ,
                                                        data: 'N/A'})
            end
          end
        }
        
      when KDDNS_SETTING_SUCCESS_RESPONSE
        msg = DDNS_SETTING_SUCCESS_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:session_id]]
        write_to_stream msg
      
      when KDDNS_SETTING_FAILURE_RESPONSE
        msg = DDNS_SETTING_FAILURE_RESPONSE % [info[:xmpp_account], @bot_xmpp_account, info[:error_code], info[:session_id]]
        write_to_stream msg
    end
  end
  
  def self.result_syslog(msg)
    Fluent::Logger.post(FLUENT_BOT_SYSINFO,
                          {event: 'SYSTEM',
                            direction: 'Device->Bot',
                            to: @bot_xmpp_account,
                            from: msg.from.to_s,
                            id: 'N/A',
                            full_domain: 'N/A',
                            message:"Receive RESULT message - %s from device" % msg.form.title ,
                            data: {xml: msg.to_s.gsub(/\n\s+/, "")}})
  end
  
  def self.submit_syslog(msg)
    Fluent::Logger.post(FLUENT_BOT_SYSINFO,
                          {event: 'SYSTEM',
                           direction: 'Device->Bot',
                           to: @bot_xmpp_account,
                           from: msg.from.to_s,
                           id: 'N/A',
                           full_domain: 'N/A',
                           message:"Receive SUBMIT message - %s from device" % msg.form.title,
                           data: {xml: msg.to_s.gsub(/\n\s+/, "")}})
  end
  
  def self.cancel_syslog(msg)
    Fluent::Logger.post(FLUENT_BOT_SYSINFO,
                          {event: 'SYSTEM',
                           direction: 'Device->Bot',
                           to: @bot_xmpp_account,
                           from: msg.from.to_s,
                           id: 'N/A',
                           full_domain: 'N/A',
                           message:"Receive CANCEL message - %s from device" % msg.form.title,
                           data: {xml: msg.to_s.gsub(/\n\s+/, "")}})
  end
  
  def self.form_syslog(msg)
    Fluent::Logger.post(FLUENT_BOT_SYSINFO,
                          {event: 'SYSTEM',
                           direction: 'Device->Bot',
                           to: @bot_xmpp_account,
                           from: msg.from.to_s,
                           id: 'N/A',
                           full_domain: 'N/A',
                           message:"Receive FORM message - %s from device" % msg.form.title,
                           data: {xml: msg.to_s.gsub(/\n\s+/, "")}})
  end
  
  #subscription :request? do |s|
  #  write_to_stream s.approve!
  #end
  disconnected {
    sleep(10)
    Fluent::Logger.post(FLUENT_BOT_SYSALERT, {event: 'SYSTEM',
                                              direction: 'N/A',
                                              to: 'N/A',
                                              from: @bot_xmpp_account,
                                              id: 'N/A',
                                              full_domain: 'N/A',
                                              message:"%s reconnect XMPP server ..." % client.jid.to_s,
                                              data: 'N/A'})
    begin
      self.run
    rescue Exception => error
      puts error
    end
    }

# Result message handler
  message :normal?, proc {|m| m.form.result? && 'pair' == m.form.title && 'start' == m.form.field('action').value} do |msg|
    begin
      result_syslog(msg)
      
      device_id = msg.thread
      device = @rd_conn.rd_pairing_session_access(device_id)
      expire_time = device["start_expire_at"] if !device.nil?
      if !device.nil? then
        data = {device_id: device_id, status: expire_time.to_i > Time.now.to_i ? KSTATUS_WAITING : KSTATUS_TIMEOUT}
        isSuccess = @rd_conn.rd_pairing_session_update(data)
        status = data[:status]
        Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                              {event: 'PAIR',
                               direction: 'Device->Bot',
                               to: @bot_xmpp_account,
                               from: msg.from.to_s,
                               id: device_id,
                               full_domain: 'N/A',
                               message:"Update the status of pairing session table to %s %s as receive PAIR START RESPONSE message from device" % [status, isSuccess ? 'success' : 'failure'] ,
                               data: 'N/A'})
      else
        Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                              {event: 'PAIR',
                               direction: 'N/A',
                               to: msg.from.to_s,
                               from: @bot_xmpp_account,
                               id: device_id,
                               full_domain: 'N/A',
                               message:"Update the status of pairing session table to WAITING failure, session id not find",
                               data: {error_code: 898}})
      end
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.result? && 'unpair' == m.form.title} do |msg|
    begin
      result_syslog(msg)
      
      device_id = msg.thread
      isSuccess = FALSE
      unpair_session = @rd_conn.rd_unpair_session_access(device_id)
      if !unpair_session.nil? then
        isSuccess = @rd_conn.rd_unpair_session_delete(device_id)
      else
        isSuccess = TRUE
      end
      
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                            {event: 'UNPAIR',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: device_id,
                             full_domain: 'N/A',
                             message:"Delete record from unpair session table %s as receive UNPAIR SUCCESS RESPONSE message from device" % [isSuccess ? 'success' : 'failure'] ,
                             data: 'N/A'})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.result? && 'set_upnp_service' == m.form.title} do |msg|
    begin
      result_syslog(msg)
      
      session_id = msg.thread
      data = {index: session_id, status: KSTATUS_UPDATED}
      isSuccess = @rd_conn.rd_upnp_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                            {event: 'UPNP',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: session_id,
                             full_domain: 'N/A',
                             message:"Update the status of unpnp session table to SUCCESS %s as receive UPNP SETTING SUCCESS RESPONSE message from device" % [isSuccess ? 'success' : 'failure'] ,
                             data: 'N/A'})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  #for DDNS settings
  message :normal?, proc {|m| m.form.result? && 'config_ddns' == m.form.title} do |msg|
    begin
      result_syslog(msg)
      
      session_id = msg.thread
      data = {index: session_id, status: KSTATUS_SUCCESS}
      isSuccess = @rd_conn.rd_ddns_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                            {event: 'DDNS',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: session_id,
                             full_domain: 'N/A',
                             message:"Update the status of ddns session table to SUCCESS %s as receive DDNS SETTING SUCCESS RESPONSE message from device" % [isSuccess ? 'success' : 'failure'] ,
                             data: 'N/A'})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end

# Submit message handler
  message :normal?, proc {|m| m.form.submit? && 'pair' == m.form.title && 'completed' == m.form.field('action').value} do |msg|
    begin
      submit_syslog(msg)
      
      device_id = msg.thread
      device = @rd_conn.rd_pairing_session_access(device_id)
      expire_time = device["waiting_expire_at"] if !device.nil?
            
      if !device.nil? then
        if expire_time.to_i > Time.now.to_i
          data = {device_id: device_id, status: KSTATUS_DONE}
          isSuccess = @rd_conn.rd_pairing_session_update(data)
          Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                {event: 'PAIR',
                                 direction: 'Device->Bot',
                                 to: @bot_xmpp_account,
                                 from: msg.from.to_s,
                                 id: device_id,
                                 full_domain: 'N/A',
                                 message:"Update the status of pairing session to COMPLETED %s as receive PAIR CONPLETED RESPONSE message from device" % [isSuccess ? 'success' : 'failure'] ,
                                 data: 'N/A'})
                
          pairing = @db_conn.db_pairing_insert(device["user_id"].to_i, device_id.to_i)
          isSuccess = @db_conn.db_pairing_update({id: pairing.id, user_id: device["user_id"].to_i, device_id: device_id.to_i, enabled: 1})
          Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                {event: 'PAIR',
                                 direction: 'N/A',
                                 to: 'N/A',
                                 from: 'N/A',
                                 id: pairing.id,
                                 full_domain: 'N/A',
                                 message:"Insert paired data into pairing table %s as receive PAIR CONPLETED RESPONSE message from device" % [isSuccess ? 'success' : 'failure'] ,
                                 data: {user_id: device["user_id"], device_id: device_id}})
            
          user = @db_conn.db_user_access(device["user_id"].to_i)
          info = {xmpp_account: msg.from, session_id: device_id, email: user.nil? ? '' : user.email}
          send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
          Fluent::Logger.post(FLUENT_BOT_FLOWINFO,
                                {event: 'PAIR',
                                 direction: 'Bot->Device',
                                 to: msg.from.to_s,
                                 from: @bot_xmpp_account,
                                 id: device_id,
                                 full_domain: 'N/A',
                                 message:"Send PAIR COMPLETED SUCCESS RESPONSE message to device after pairing successful",
                                 data: {email: user.nil? ? 'user email invalid' : user.email}})
        else
          data = {device_id: device_id, status: KSTATUS_TIMEOUT}
          isSuccess = @rd_conn.rd_pairing_session_update(data)
            
          info = {xmpp_account: msg.from, error_code: 899, session_id: device_id}
          send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
          Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                {event: 'PAIR',
                                 direction: 'Bot->Device',
                                 to: msg.from.to_s,
                                 from: @bot_xmpp_account,
                                 id: device_id,
                                 full_domain: 'N/A',
                                 message:"Send PAIR COMPLETED FAILURE RESPONSE message to device as pairing timeout, and update the status of pairing session to FAILURE %s" % [isSuccess ? 'success' : 'failure'],
                                 data: {error_code: 899}})
        end
      else
        info = {xmpp_account: msg.from, error_code: 898, session_id: device_id}
        send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
        Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                              {event: 'PAIR',
                               direction: 'Bot->Device',
                               to: msg.from.to_s,
                               from: @bot_xmpp_account,
                               id: device_id,
                               full_domain: 'N/A',
                               message:"Send PAIR COMPLETED FAILURE RESPONSE message to device as session id not find",
                               data: {error_code: 898}})
      end
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end

  # Pair timeout
  message :normal?, proc {|m| m.form.submit? && 'pair' == m.form.title && 'cancel' == m.form.field('action').value} do |msg|
    begin
      submit_syslog(msg)
      
      device_id = msg.thread
      pair_session = @rd_conn.rd_pairing_session_access(device_id)
            
      if !pair_session.nil? then
        data = {device_id: device_id, status: KSTATUS_TIMEOUT}
        isSuccess = @rd_conn.rd_pairing_session_update(data)
        Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                              {event: 'PAIR',
                               direction: 'Device->Bot',
                               to: @bot_xmpp_account,
                               from: msg.from.to_s,
                               id: device_id,
                               full_domain: 'N/A',
                               message:"Update the status of pairing session to 'TIMEOUT' %s as receive PAIR TIMEOUT RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                               data: 'N/A'})
            
        if isSuccess
          info = {xmpp_account: msg.from, session_id: device_id}
          send_request(KPAIR_TIMEOUT_SUCCESS_RESPONSE, info)
          Fluent::Logger.post(FLUENT_BOT_FLOWINFO,
                                {event: 'PAIR',
                                 direction: 'Bot->Device',
                                 to: msg.from.to_s,
                                 from: @bot_xmpp_account,
                                 id: device_id,
                                 full_domain: 'N/A',
                                 message:"Send PAIR TIMEOUT SUCCESS RESPONSE message to device as update pairing session table success",
                                 data: 'N/A'})
        else
          info = {xmpp_account: msg.from, error_code: 897, session_id: device_id}
          send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
          Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                                {event: 'PAIR',
                                 direction: 'Bot->Device',
                                 to: msg.from.to_s,
                                 from: @bot_xmpp_account,
                                 id: device_id,
                                 full_domain: 'N/A',
                                 message:"Send PAIR TIMEOUT FAILURE RESPONSE message to device as update pairing session table failure",
                                 data: {error_code: 897}})
        end
      else
        info = {xmpp_account: msg.from, error_code: 898, session_id: device_id}
        send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
        Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                              {event: 'PAIR',
                               direction: 'Bot->Device',
                               to: msg.from.to_s,
                               from: @bot_xmpp_account,
                               id: device_id,
                               full_domain: 'N/A',
                               message:"Send PAIR TIMEOUT FAILURE RESPONSE message to device as pairing session id not find",
                               data: {error_code: 898}})
      end
      
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  # DDNS Setting from device
  message :normal?, proc {|m| m.form.submit? && 'config_ddns' == m.form.title} do |msg|
    begin
      submit_syslog(msg)
      
      session_id = msg.thread
      host_name = nil
      domain_name = nil
      msg.form.fields.each do |field|
        host_name = field.value.downcase if 'hostname_prefix' == field.var
        domain_name = field.value.downcase if 'hostname_suffix' == field.var
      end
          
      regex = /^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\-]*[a-zA-Z0-9])\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\-]*[A-Za-z0-9])(.)$/
      dns_valid = regex.match(host_name + '.' + domain_name)
          
      domain_name += '.' if '.' != domain_name[-1, 1]

      isValidZoneName = FALSE
      @route_conn.zones_list.each do |zone|
        isValidZoneName = TRUE if domain_name.downcase == zone["name"].downcase
      end
      
      is_invalid_length = (host_name.length > 63 || host_name.length < 3)
      
      isReserved = FALSE
      @route_conn.reserved_hostname.each do |host|
        isReserved = TRUE if host == host_name
      end

      if !host_name.empty? && !domain_name.empty? && !dns_valid.nil? && isValidZoneName && !is_invalid_length && !isReserved then
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
                
            EM.defer {
              session_id = x[:session_id]
              ddns_record = @db_conn.db_ddns_access({device_id: device_id})
              record_info = {host_name: x[:host_name], domain_name: x[:domain_name], ip: x[:device_ip]}
              isSuccess = @route_conn.create_record(record_info)
              Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                    {event: 'DDNS',
                                     direction: 'N/A',
                                     to: 'N/A',
                                     from: 'N/A',
                                     id: 'N/A',
                                     full_domain: x[:host_name] + '.' + x[:domain_name],
                                     message:"Create Route53 DDNS record %s as received DDNS SETTING REQUEST message from device" % [isSuccess ? 'success' : 'failure'],
                                     data: {ip: x[:device_ip]}})
              
              if !ddns_record.nil? && isSuccess then
                domain_S = ddns_record.full_domain.to_s.split('.')
                host_name = domain_S[0]
                domain_S.shift
                domain_name = domain_S.join('.')
                domain_name += '.' if '.' != domain_name[-1, 1]

                data = {id: ddns_record.id, full_domain: x[:host_name] + '.' + x[:domain_name], ip_address: x[:device_ip]}
                isSuccess =  @db_conn.db_ddns_update(data)
                Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                      {event: 'DDNS',
                                       direction: 'N/A',
                                       to: 'N/A',
                                       from: 'N/A',
                                       id: ddns_record.id,
                                       full_domain: x[:host_name] + '.' + x[:domain_name],
                                       message:"Update DDNS table %s as received DDNS SETTING REQUEST message from device" % [isSuccess ? 'success' : 'failure'],
                                       data: {ip: x[:device_ip]}})

                if host_name != x[:host_name] || domain_name != x[:domain_name] then
                  record_info = {host_name: host_name, domain_name: domain_name}
                  isSuccess = @route_conn.delete_record(record_info)
                  Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWERROR,
                                        {event: 'DDNS',
                                         direction: 'N/A',
                                         to: 'N/A',
                                         from: 'N/A',
                                         id: 'N/A',
                                         full_domain: host_name + '.' + domain_name,
                                         message:"Delete previous record from DDNS table %s as received DDNS SETTING REQUEST message from device" % [isSuccess ? 'success' : 'failure'],
                                         data: 'N/A'})
                end
              end
                
              if isSuccess then
                record = {device_id: x[:device_id], ip_address: x[:device_ip], full_domain: x[:host_name] + '.' + x[:domain_name]}
                @db_conn.db_ddns_insert(record) if ddns_record.nil?

                ddns_retry_session = @db_conn.db_ddns_retry_session_access({full_domain: x[:host_name] + '.' + x[:domain_name]})
                @db_conn.db_ddns_retry_session_delete(ddns_retry_session.id) if !ddns_retry_session.nil?

                info = {xmpp_account: x[:msg_from], session_id: session_id}
                send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
                Fluent::Logger.post(FLUENT_BOT_FLOWINFO,
                                      {event: 'DDNS',
                                       direction: 'Bot->Device',
                                       to: x[:msg_from],
                                       from: @bot_xmpp_account,
                                       id: 'N/A',
                                       full_domain: x[:host_name] + '.' + x[:domain_name],
                                       message:"Send DDNS SETTING SUCCESS RESPONSE message to device as create Route53 DDNS record success",
                                       data: {ip: x[:device_ip], device_id: x[:device_id]}})
              else
                info = info = {xmpp_account: x[:msg_from], error_code: 997, session_id: session_id}
                send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                                      {event: 'DDNS',
                                       direction: 'Bot->Device',
                                       to: x[:msg_from],
                                       from: @bot_xmpp_account,
                                       id: 'N/A',
                                       full_domain: x[:host_name] + '.' + x[:domain_name],
                                       message:"Send DDNS SETTING FAILURE RESPONSE message to device as create Route53 DDNS record failure",
                                       data: {error_code: 997}})

                @db_conn.db_ddns_retry_session_insert({device_id: x[:device_id], full_domain: x[:host_name] + '.' + x[:domain_name]})

                user_email = @db_conn.db_retrive_user_email_by_xmpp_account(x[:xmpp_account])
                isSuccess = @mail_conn.send_offline_mail(user_email) if !user_email.nil?
                Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWERROR,
                                        {event: 'DDNS',
                                         direction: 'N/A',
                                         to: 'N/A',
                                         from: 'N/A',
                                         id: 'N/A',
                                         full_domain: 'N/A',
                                         message:"Send DDNS offline email to user %s" % [isSuccess ? 'success' : 'failure'],
                                         data: {user_email: user_email}})
              end
            }
            #routeThread.abort_on_exception = TRUE
          }
              
        elsif !device_id.nil? && !old_device_id.nil? then
          if device_id == old_device_id then
            data = {host_name: host_name,
                    domain_name: domain_name,
                    device_ip: device_ip,
                    device_id: device_id,
                    session_id: msg.thread,
                    msg_from: msg.from.to_s,
                    xmpp_account: msg.from.node
                  }
            container(data){
              |x|
              EM.defer {
                session_id = x[:session_id]
              
                ddns_record = @db_conn.db_ddns_access({device_id: x[:device_id]})
                record_info = {host_name: x[:host_name], domain_name: x[:domain_name], ip: x[:device_ip]}
                isSuccess = @route_conn.create_record(record_info)
                Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                      {event: 'DDNS',
                                       direction: 'N/A',
                                       to: 'N/A',
                                       from: 'N/A',
                                       id: 'N/A',
                                       full_domain: x[:host_name] + '.' + x[:domain_name],
                                       message:"Create Route53 DDNS record %s as received DDNS SETTING REQUEST message from device" % [isSuccess ? 'success' : 'failure'],
                                       data: {ip: x[:device_ip]}})
              
                if !ddns_record.nil? && isSuccess then
                  domain_S = ddns_record.full_domain.to_s.split('.')
                  host_name = domain_S[0]
                  domain_S.shift
                  domain_name = domain_S.join('.')
                  domain_name += '.' if '.' != domain_name[-1, 1]

                  data = {id: ddns_record.id, full_domain: x[:host_name] + '.' + x[:domain_name], ip_address: x[:device_ip]}
                  isSuccess =  @db_conn.db_ddns_update(data)
                  Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                                        {event: 'DDNS',
                                         direction: 'N/A',
                                         to: 'N/A',
                                         from: 'N/A',
                                         id: ddns_record.id,
                                         full_domain: x[:host_name] + '.' + x[:domain_name],
                                         message:"Update DDNS table %s as received DDNS SETTING REQUEST message from device" % [isSuccess ? 'success' : 'failure'],
                                         data: {ip: x[:device_ip]}})

                  if host_name != x[:host_name] || domain_name != x[:domain_name] then
                    record_info = {host_name: host_name, domain_name: domain_name}
                    isSuccess = @route_conn.delete_record(record_info)
                    Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWERROR,
                                          {event: 'DDNS',
                                           direction: 'N/A',
                                           to: 'N/A',
                                           from: 'N/A',
                                           id: 'N/A',
                                           full_domain: host_name + '.' + domain_name,
                                           message:"Delete previous record from DDNS table %s as received DDNS SETTING REQUEST message from device" % [isSuccess ? 'success' : 'failure'],
                                           data: 'N/A'})
                  end
                end

                if isSuccess then
                  info = info = {xmpp_account: x[:msg_from], session_id: session_id}
                  send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
                  Fluent::Logger.post(FLUENT_BOT_FLOWINFO,
                                        {event: 'DDNS',
                                         direction: 'Bot->Device',
                                         to: x[:msg_from],
                                         from: @bot_xmpp_account,
                                         id: 'N/A',
                                         full_domain: x[:host_name] + '.' + x[:domain_name],
                                         message:"Send DDNS SETTING SUCCESS RESPONSE message to device as create Route53 DDNS record success",
                                         data: {ip: x[:device_ip], device_id: x[:device_id]}})
                else
                  info = info = {xmpp_account: x[:msg_from], error_code: 997, session_id: session_id}
                  send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
                  Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                                        {event: 'DDNS',
                                         direction: 'Bot->Device',
                                         to: x[:msg_from],
                                         from: @bot_xmpp_account,
                                         id: 'N/A',
                                         full_domain: x[:host_name] + '.' + x[:domain_name],
                                         message:"Send DDNS SETTING FAILURE RESPONSE message to device as create Route53 DDNS record failure",
                                         data: {error_code: 997}})

                  @db_conn.db_ddns_retry_session_insert({device_id: x[:device_id], full_domain: x[:host_name] + '.' + x[:domain_name]})

                  user_email = @db_conn.db_retrive_user_email_by_xmpp_account(x[:xmpp_account])
                  isSuccess = @mail_conn.send_offline_mail(user_email) if !user_email.nil?
                  Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWERROR,
                                        {event: 'DDNS',
                                         direction: 'N/A',
                                         to: 'N/A',
                                         from: 'N/A',
                                         id: 'N/A',
                                         full_domain: 'N/A',
                                         message:"Send DDNS offline email to user %s" % [isSuccess ? 'success' : 'failure'],
                                         data: {user_email: user_email}})
                end
              }
              #routeThread.abort_on_exception = TRUE
            }
          else
            info = info = {xmpp_account: msg.from, error_code: 995, session_id: msg.thread}
            send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
            Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                                  {event: 'DDNS',
                                   direction: 'Bot->Device',
                                   to: msg.from.to_s,
                                   from: @bot_xmpp_account,
                                   id: 'N/A',
                                   full_domain: host_name + '.' + domain_name,
                                   message:"Send DDNS SETTING FAILURE RESPONSE message to device as DNS has been used to other device",
                                   data: {error_code: 995}})
          end
        else
          info = info = {xmpp_account: msg.from, error_code: 998, session_id: msg.thread}
          send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
          Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                                {event: 'DDNS',
                                 direction: 'Bot->Device',
                                 to: msg.from.to_s,
                                 from: @bot_xmpp_account,
                                 id: 'N/A',
                                 full_domain: host_name + '.' + domain_name,
                                 message:"Send DDNS SETTING FAILURE RESPONSE message to device as device ip not find",
                                 data: {ip: device_ip, error_code: 998}})
        end
      else
        info = info = {xmpp_account: msg.from, error_code: 999, session_id: msg.thread}
        send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
        Fluent::Logger.post(FLUENT_BOT_FLOWERROR,
                              {event: 'DDNS',
                               direction: 'Bot->Device',
                               to: msg.from.to_s,
                               from: @bot_xmpp_account,
                               id: 'N/A',
                               full_domain: host_name + '.' + domain_name,
                               message:"Send DDNS SETTING FAILURE RESPONSE message to device as DNS format invalid",
                               data: {error_code: 995}})
      end
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  # Cancel message handler
  message :normal?, proc {|m| m.form.cancel? && 'pair' == m.form.title && 'start' == m.form.field('action').value} do |msg|
    begin
      cancel_syslog(msg)
      
      device_id = msg.thread
      data = {device_id: device_id, status: KSTATUS_FAILURE}
      error_code = msg.form.field('ERROR_CODE').value
      isSuccess = @rd_conn.rd_pairing_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'PAIR',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: device_id,
                             full_domain: 'N/A',
                             message:"Update the status of pairing session to FAILURE %s as receive PAIR START FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {error_code: error_code}})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.cancel? && 'pair' == m.form.title && 'completed' == m.form.field('action').value} do |msg|
    begin
      cancel_syslog(msg)
      
      device_id = msg.thread
      data = {device_id: device_id, status: KSTATUS_FAILURE}
      error_code = msg.form.field('ERROR_CODE').value
      isSuccess = @rd_conn.rd_pairing_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'PAIR',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: device_id,
                             full_domain: 'N/A',
                             message:"Update the status of pairing session to FAILURE %s as receive START COMPLETED FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {error_code: error_code}})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.cancel? && 'pair' == m.form.title && 'cancel' == m.form.field('action').value} do |msg|
    begin
      cancel_syslog(msg)
      
      device_id = msg.thread
      data = {device_id: device_id, status: KSTATUS_FAILURE}
      error_code = msg.form.field('ERROR_CODE').value
      isSuccess = @rd_conn.rd_pairing_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'PAIR',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: device_id,
                             full_domain: 'N/A',
                             message:"Update the status of pairing session to FAILURE %s as receive START COMPLETED FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {error_code: error_code}})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.cancel? && 'unpair' == m.form.title} do |msg|
    begin
      cancel_syslog(msg)
      
      device_id = msg.thread
      error_code = msg.form.field('ERROR_CODE').value
      isSuccess = FALSE
      unpair_session = @rd_conn.rd_unpair_session_access(device_id)
      if !unpair_session.nil? then
        isSuccess = @rd_conn.rd_unpair_session_delete(device_id)
      else
        isSuccess = TRUE
      end
      
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'UNPAIR',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: device_id,
                             full_domain: 'N/A',
                             message:"Delete the record of unpair session %s as receive UNPAIR FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {error_code: error_code}})
      
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.cancel? && 'get_upnp_service' == m.form.title} do |msg|
    begin
      cancel_syslog(msg)
      
      session_id = msg.thread
      error_code = msg.form.field('ERROR_CODE').value
      data = {index: session_id, status: KSTATUS_FAILURE}
      isSuccess = @rd_conn.rd_upnp_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'UPNP',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: session_id,
                             full_domain: 'N/A',
                             message:"Update the status of upnp session to FAILURE %s as receive UPNP GET SETTING FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {error_code: error_code}})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.cancel? && 'set_upnp_service' == m.form.title} do |msg|
    begin
      cancel_syslog(msg)
      
      hasX = FALSE
      hasITEM = FALSE
      session_id = msg.thread
      error_code_record = Array.new
      
      upnp_session = @rd_conn.rd_upnp_session_access(session_id)
      if !upnp_session.nil? then
        service_list = JSON.parse(upnp_session["service_list"].to_s)
      
        MultiXml.parser = :rexml
        xml = MultiXml.parse(msg.form.to_s)
        hasX = xml.has_key?("x")
        hasITEM = xml["x"].has_key?("item") if hasX
      
        if !xml.nil? && hasX && hasITEM then
        
          if !xml["x"]["item"].instance_of?(Array) then
            items = Array.new
            items << xml["x"]["item"]
            xml["x"]["item"] = items
          end
        
          xml["x"]["item"].each do |item|
            servicename = nil
            error_code = nil
          
            item["field"].each do |field|
              var = field["var"]
              case var
                when 'servicename'
                  servicename = field["value"]
                when 'ERROR_CODE'
                  error_code = field["value"]
              end
            end
          
            service_list.each do |service|
              if service["service_name"] == servicename then
                service["error_code"] = error_code
              end
            end
          
            error_code_record << {service_name: servicename, error_code: error_code}
          end
        end
      
        service_list_json = JSON.generate(service_list)
      
        data = {index: session_id, status: KSTATUS_FORM, service_list: service_list_json}
        isSuccess = @rd_conn.rd_upnp_session_update(data)
        Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                              {event: 'UPNP',
                               direction: 'Device->Bot',
                               to: @bot_xmpp_account,
                               from: msg.from.to_s,
                               id: session_id,
                               full_domain: 'N/A',
                               message:"Update the status of upnp session to FAILURE %s as receive UPNP SET SETTING FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                               data: {error_code: JSON.generate(error_code_record)}})
      else
        Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'UPNP',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: session_id,
                             full_domain: 'N/A',
                             message:"Update the status of upnp session failure, session id not find",
                             data: {error_code: 798}})
      end
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  message :normal?, proc {|m| m.form.cancel? && 'config_ddns' == m.form.title} do |msg|
    begin
      cancel_syslog(msg)
      
      session_id = msg.thread
      error_code = msg.form.field('ERROR_CODE').value
      data = {id: session_id, status:3}
      isSuccess = @db_conn.db_ddns_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWERROR : FLUENT_BOT_FLOWALERT,
                            {event: 'DDNS',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: session_id,
                             full_domain: 'N/A',
                             message:"Update the status of ddns session to FAILURE %s as receive DDNS SETTING FAILURE RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {error_code: error_code}})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
  
  # Form message handler
  message :normal?, proc {|m| m.form.form? && 'get_upnp_service' == m.form.title} do |msg|
    begin
      form_syslog(msg)
      
      hasX = nil
      hasITEM = nil
      session_id = msg.thread
      service_list = Array.new
          
      MultiXml.parser = :rexml
      xml = MultiXml.parse(msg.form.to_s)
      hasX = xml.has_key?("x")
      hasITEM = xml["x"].has_key?("item") if hasX
      lan_ip = xml["x"]["field"]["value"] if xml["x"].has_key?("field") && 'lanip' == xml["x"]["field"]["var"]
 
      if !xml.nil? && hasX && hasITEM then
        
        if !xml["x"]["item"].instance_of?(Array) then
          items = Array.new
          items << xml["x"]["item"]
          xml["x"]["item"] = items
        end
        
        xml["x"]["item"].each do |item|
        service_name = ''
        status = false
        enabled = false
        description = ''
        path = ''
        port = ''

        item["field"].each do |field|
          var = field["var"]
          case var
            when 'service-name'
              service_name = field["value"].nil? ? '' : field["value"]
            when 'status'
              status = field["value"] == 'true' ? true : false
            when 'enabled'
              enabled = field["value"] == 'true' ? true : false
            when 'description'
              description = field["value"]
            when 'path'
              path = field["value"].nil? ? '' : field["value"]
            when 'port'
              port = field["value"].nil? ? '' : field["value"]
          end
        end
            
        service = {:service_name => service_name,
                   :status => status,
                   :enabled => enabled,
                   :description => description,
                   :path => path,
                   :port => port,
                   :error_code => ''
                  }
        service_list << service
      end
          
        service_list_json = JSON.generate(service_list)
      else
        service_list_json = ''
      end
          
      data = {index: session_id, status: KSTATUS_FORM, service_list: service_list_json, lan_ip: lan_ip}
      isSuccess = @rd_conn.rd_upnp_session_update(data)
      Fluent::Logger.post(isSuccess ? FLUENT_BOT_FLOWINFO : FLUENT_BOT_FLOWALERT,
                            {event: 'UPNP',
                             direction: 'Device->Bot',
                             to: @bot_xmpp_account,
                             from: msg.from.to_s,
                             id: session_id,
                             full_domain: 'N/A',
                             message:"Update the status & service list of ddns session %s as receive DDNS SETTING RESPONSE message from device" % [isSuccess ? 'success' : 'failure'],
                             data: {service_list: service_list_json}})
    rescue Exception => error
      Fluent::Logger.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
  end
end
