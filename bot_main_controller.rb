#!/usr/bin/env ruby

$stdout.sync = true

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_redis_access'
require_relative 'lib/bot_xmpp_controller'
require 'fluent-logger'

FLUENT_BOT_SYSINFO = "bot.sys-info"
FLUENT_BOT_SYSERROR = "bot.sys-error"
FLUENT_BOT_SYSALERT = "bot.sys-alert"
FLUENT_BOT_FLOWINFO = "bot.flow-info"
FLUENT_BOT_FLOWERROR = "bot.flow-error"
FLUENT_BOT_FLOWALERT = "bot.flow-alert"

xmpp_connect_ready = FALSE
threads = Array.new

Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)

def get_xmpp_config
  input = ARGV
  account = nil
  password = nil
  #length = input.length - 1

  for i in 0..(input.length - 1)
    option = input[i]
    account = input[i + 1] if '-u' == option
    password = input[i + 1] if '-p' == option
  end
  return {jid: account, pw: password}
end

XMPP_CONFIG = get_xmpp_config

jobThread = Thread.new {
    Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                             direction: 'N/A',
                                             to: 'N/A',
                                             form: 'N/A',
                                             id: 'N/A',
                                             full_domain: 'N/A',
                                             message:"XMPP Controll running ...",
                                             data: 'N/A'})
    XMPPController.new(XMPP_CONFIG[:jid], XMPP_CONFIG[:pw])
    XMPPController.run
}
jobThread.abort_on_exception = TRUE
threads << jobThread

XMPPController.when_ready { xmpp_connect_ready = TRUE }

db_conn = BotDBAccess.new
rd_conn = BotRedisAccess.new

ddnsThread = Thread.new{
  Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                           direction: 'N/A',
                                           to: 'N/A',
                                           form: 'N/A',
                                           id: 'N/A',
                                           full_domain: 'N/A',
                                           message:"Start re-update DDNS record ...",
                                           data: 'N/A'})
  loop do
    sleep(30)
    Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                             direction: 'N/A',
                                             to: 'N/A',
                                             form: 'N/A',
                                             id: 'N/A',
                                             full_domain: 'N/A',
                                             message:"Retry register DDNS record ...",
                                             data: 'N/A'})
    XMPPController.retry_ddns_register
  end
}
ddnsThread.abort_on_exception = TRUE
threads << ddnsThread

while !xmpp_connect_ready
  Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                           direction: 'N/A',
                                           to: 'N/A',
                                           form: 'N/A',
                                           id: 'N/A',
                                           full_domain: 'N/A',
                                           message:"Waiting XMPP connection ready ...",
                                           data: 'N/A'})
  sleep(2)
end
Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                         direction: 'N/A',
                                         to: 'N/A',
                                         form: 'N/A',
                                         id: 'N/A',
                                         full_domain: 'N/A',
                                         message:"XMPP connection ready",
                                         data: 'N/A'})

def worker(sqs, db_conn, rd_conn)
  sqs.sqs_listen{
    |job, data|
  
    case job
      when 'pairing' then
        device_id = data[:device_id]
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'PAIR',
                                                  direction: 'N/A',
                                                  to: 'N/A',
                                                  form: 'N/A',
                                                  id: device_id,
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of pairing",
                                                  data: 'N/A'})
        
        device = rd_conn.rd_device_session_access(device_id)
        xmpp_account = nil != device ? device["xmpp_account"] : nil
        info = {xmpp_account: xmpp_account.to_s,
                device_id: device_id}
        
        XMPPController.send_request(KPAIR_START_REQUEST, info) if !xmpp_account.nil?

      when 'unpair' then
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UNPAIR',
                                                  direction: 'N/A',
                                                  to: 'N/A',
                                                  form: 'N/A',
                                                  id: 'N/A',
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of unpair", data: data})
        
        device_id = data[:device_id]
        device = rd_conn.rd_device_session_access(device_id)
        xmpp_account = !device.nil? ? device["xmpp_account"] : ''
        rd_conn.rd_unpair_session_insert(device_id) if !device.nil?
        ddns = db_conn.db_ddns_access({device_id: device_id})
        full_domain = !ddns.nil? ? ddns.full_domain : nil
        
        info = {xmpp_account: xmpp_account,
                session_id: device_id,
                full_domain: full_domain
                }
        
        XMPPController.send_request(KUNPAIR_ASK_REQUEST, info) if !device.nil?
      
      when 'upnp_submit' then
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                  direction: 'N/A',
                                                  to: 'N/A',
                                                  form: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of upnp-submit", data: data})
        
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_upnp_session_id(session_id)
        service_list = db_conn.db_upnp_session_access({id: session_id}).service_list.to_s
        language = db_conn.db_retrive_user_local_by_upnp_session_id(session_id)
        
        field_item = ""
        
        if valid_json? service_list then
          service_list_json = JSON.parse(service_list)
          service_list_json.each do |item|
            service_name = item["service_name"]
            status = item["status"].to_s
            enabled = item["enabled"].to_s
            description = item["description"]
            path = item["path"]
            port = item["port"]
            
            field_item += UPNP_FIELD_ITEM % [service_name, status, enabled, description, path, port]
          end
        end
        
        info = {xmpp_account: xmpp_account.to_s,
                language: language.to_s,
                session_id: session_id,
                field_item: field_item}
        XMPPController.send_request(KUPNP_SETTING_REQUEST, info) if !xmpp_account.nil? && !language.nil?
      
      when 'upnp_query' then
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                  direction: 'N/A',
                                                  to: 'N/A',
                                                  form: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of upnp-query", data: data})
        
        session_id = data[:session_id]
        language = db_conn.db_retrive_user_local_by_upnp_session_id(session_id)
        xmpp_account = db_conn.db_retreive_xmpp_account_by_upnp_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s,
                language: language.to_s,
                session_id: data[:session_id]}
        
        XMPPController.send_request(KUPNP_ASK_REQUEST, info) if !xmpp_account.nil? && !language.nil?
      
      when 'ddns' then
        Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'DDNS',
                                                  direction: 'N/A',
                                                  to: 'N/A',
                                                  form: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of DDNS-query", data: data})
        
        session_id = data[:session_id]
        ddns_session = db_conn.db_ddns_session_access({id: session_id})
        xmpp_account = db_conn.db_retreive_xmpp_account_by_ddns_session_id(session_id)
        device_session = db_conn.db_device_session_access({xmpp_account: xmpp_account})
        
        info = {xmpp_account: xmpp_account.to_s,
                session_id: data[:session_id],
                device_id: !ddns_session.nil? ? ddns_session.device_id : '',
                ip: !device_session.nil? ? device_session.ip : '',
                full_domain: !ddns_session.nil? ? ddns_session.full_domain : ''}
        
        XMPPController.send_request(KDDNS_SETTING_REQUEST, info) if !xmpp_account.nil? && !ddns_session.nil? && !device_session.nil?
    end
    
    job = nil
    data = nil
  }
end

sqs = BotQueueAccess.new

60.times do |d|
  sqsThread = Thread.new{ worker(sqs, db_conn, rd_conn) }
  sqsThread.abort_on_exception = TRUE
  threads << sqsThread
end

worker(sqs, db_conn, rd_conn)