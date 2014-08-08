#!/usr/bin/env ruby

$stdout.sync = true

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_xmpp_controller'
require 'fluent-logger'

XMPP_SERVER_DOMAIN = '@xmpp.pcloud.ecoworkinc.com'
XMPP_RESOURCE_ID = '/device'

FLUENT_BOT_SYSINFO = "bot.sys-info"
FLUENT_BOT_SYSERROR = "bot.sys-error"
FLUENT_BOT_SYSALERT = "bot.sys-alert"
FLUENT_BOT_FLOWINFO = "bot.flow-info"
FLUENT_BOT_FLOWERROR = "bot.flow-error"
FLUENT_BOT_FLOWALERT = "bot.flow-alert"

xmpp_connect_ready = FALSE

Fluent::Logger::FluentLogger.open(nil, :host=>'localhost', :port=>24224)

jobThread = Thread.new {
    Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                             direction: 'N/A',
                                             to: 'N/A',
                                             form: 'N/A',
                                             id: 'N/A',
                                             full_domain: 'N/A',
                                             message:"XMPP Controll running ...",
                                             data: 'N/A'})
    XMPPController.new
    XMPPController.run
}
jobThread.abort_on_exception = TRUE

XMPPController.when_ready { xmpp_connect_ready = TRUE }

db_conn = BotDBAccess.new

timeoutThread = Thread.new{
  Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                           direction: 'N/A',
                                           to: 'N/A',
                                           form: 'N/A',
                                           id: 'N/A',
                                           full_domain: 'N/A',
                                           message:"Updating timeout pairing session ...",
                                           data: 'N/A'})
  loop do
    sleep(30.0)
    data = db_conn.db_pairing_session_access_timeout
    Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                             direction: 'N/A',
                                             to: 'N/A',
                                             form: 'N/A',
                                             id: 'N/A',
                                             full_domain: 'N/A',
                                             message:"Search timeout pairing session ...",
                                             data: 'N/A'})
    
    data.find_each do |row|
      data = {id: row.id, status: 4}
      isSuccess = db_conn.db_pairing_session_update(data)
      Fluent::Logger.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                               direction: 'N/A',
                                               to: 'N/A',
                                               form: 'N/A',
                                               id: 'N/A',
                                               full_domain: 'N/A',
                                               message:"Update timeout pairing session id:%d %s ..." % [row.id, isSuccess ? 'success' : 'failure'],
                                               data: 'N/A'})
    end
  end
}
timeoutThread.abort_on_exception = TRUE

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

sqs = BotQueueAccess.new
sqs.sqs_listen{
  |job, data|
  
  case job
    when 'pairing' then
      Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'PAIR',
                                                direction: 'N/A',
                                                to: 'N/A',
                                                form: 'N/A',
                                                id: data[:session_id],
                                                full_domain: 'N/A',
                                                message:"Get SQS queue of pairing",
                                                data: 'N/A'})
      pairThread = Thread.new{
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_pair_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id]}
        
        XMPPController.send_request(KPAIR_START_REQUEST, info) if !xmpp_account.nil?
      }
      pairThread.abort_on_exception = FALSE

    when 'unpair' then
      Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UNPAIR',
                                                direction: 'N/A',
                                                to: 'N/A',
                                                form: 'N/A',
                                                id: 'N/A',
                                                full_domain: 'N/A',
                                                message:"Get SQS queue of unpair", data: data})
      unpairThread = Thread.new{
        device_id = data[:device_id]
        device_session = db_conn.db_device_session_access({device_id: device_id})
        xmpp_account = !device_session.nil? ? device_session.xmpp_account : ''
        unpair_session = db_conn.db_unpair_session_insert({device_id: device_id})
        ddns = db_conn.db_ddns_access({device_id: device_id})
        full_domain = !ddns.nil? ? ddns.full_domain : nil
        
        info = {xmpp_account: xmpp_account + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: unpair_session.id,
                full_domain: full_domain
                }
        
        XMPPController.send_request(KUNPAIR_ASK_REQUEST, info) if !device_session.nil?
      }
      unpairThread.abort_on_exception = FALSE
      
    when 'upnp_submit' then
      Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                direction: 'N/A',
                                                to: 'N/A',
                                                form: 'N/A',
                                                id: data[:session_id],
                                                full_domain: 'N/A',
                                                message:"Get SQS queue of upnp-submit", data: data})
      upnpSubmitThread = Thread.new {
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
            
            field_item += UPNP_FIELD_ITEM % [service_name, status, enabled, description]
          end
        end
        
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                language: language.to_s,
                session_id: session_id,
                field_item: field_item}
        XMPPController.send_request(KUPNP_SETTING_REQUEST, info) if !xmpp_account.nil? && !language.nil?
      }
      upnpSubmitThread.abort_on_exception = FALSE
      
    when 'upnp_query' then
      Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                direction: 'N/A',
                                                to: 'N/A',
                                                form: 'N/A',
                                                id: data[:session_id],
                                                full_domain: 'N/A',
                                                message:"Get SQS queue of upnp-query", data: data})
      upnpQueryThread = Thread.new{
        session_id = data[:session_id]
        language = db_conn.db_retrive_user_local_by_upnp_session_id(session_id)
        xmpp_account = db_conn.db_retreive_xmpp_account_by_upnp_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                language: language.to_s,
                session_id: data[:session_id]}
        
        XMPPController.send_request(KUPNP_ASK_REQUEST, info) if !xmpp_account.nil? && !language.nil?
      }
      upnpQueryThread.abort_on_exception = FALSE
      
    when 'ddns' then
      Fluent::Logger.post(FLUENT_BOT_FLOWINFO, {event: 'DDNS',
                                                direction: 'N/A',
                                                to: 'N/A',
                                                form: 'N/A',
                                                id: data[:session_id],
                                                full_domain: 'N/A',
                                                message:"Get SQS queue of DDNS-query", data: data})
      ddnsQueryThread = Thread.new{
        session_id = data[:session_id]
        ddns_session = db_conn.db_ddns_session_access({id: session_id})
        xmpp_account = db_conn.db_retreive_xmpp_account_by_ddns_session_id(session_id)
        device_session = db_conn.db_device_session_access({xmpp_account: xmpp_account})
        
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id],
                device_id: !ddns_session.nil? ? ddns_session.device_id : '',
                ip: !device_session.nil? ? device_session.ip : '',
                full_domain: !ddns_session.nil? ? ddns_session.full_domain : ''}
        
        XMPPController.send_request(KDDNS_SETTING_REQUEST, info) if !xmpp_account.nil? && !ddns_session.nil? && !device_session.nil?
      }
      ddnsQueryThread.abort_on_exception = TRUE
  end
}
