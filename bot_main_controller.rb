#!/usr/bin/env ruby

$stdout.sync = true

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_xmpp_controller'

XMPP_SERVER_DOMAIN = '@xmpp.pcloud.ecoworkinc.com'
XMPP_RESOURCE_ID = '/device'

xmpp_connect_ready = FALSE

jobThread = Thread.new {
    puts 'Pair controll running'
    XMPPController.new
    XMPPController.run
}
jobThread.abort_on_exception = TRUE

XMPPController.when_ready { xmpp_connect_ready = TRUE }

db_conn = BotDBAccess.new

timeoutThread = Thread.new{
  puts 'Timeout update running'
  loop do
    sleep(30.0)
    data = db_conn.db_pairing_session_access_timeout
    puts 'Search timeout session'
    
    data.find_each do |row|
      data = {id: row.id, status: 4}
      isSuccess = db_conn.db_pairing_session_update(data)
      'Update timeout session success' if isSuccess
    end
  end
}
timeoutThread.abort_on_exception = TRUE

ddnsThread = Thread.new{
  puts '[%s] DDNS re-update running' % DateTime.now
  loop do
    sleep(30)
    puts '[%s] Retry DDNS register' % DateTime.now
    XMPPController.retry_ddns_register
  end
}
ddnsThread.abort_on_exception = TRUE

while !xmpp_connect_ready
  puts '[%s] Waiting XMPP connection ready' % DateTime.now
  sleep(2)
end
puts '[%s] XMPP connection ready' % DateTime.now

sqs = BotQueueAccess.new
sqs.sqs_listen{
  |job, data|
  
  case job
    when 'pairing' then
      puts 'Get SQS Pairing message %s' % data
      pairThread = Thread.new{
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_pair_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id]}
        
        XMPPController.send_request(KPAIR_START_REQUEST, info) if !xmpp_account.nil?
      }
      pairThread.abort_on_exception = FALSE

    when 'unpair' then
      puts 'Get SQS Unpair message %s' % data
      unpairThread = Thread.new{
        device_id = data[:device_id]
        device_session = db_conn.db_device_session_access({device_id: device_id})
        xmpp_account = !device_session.nil? ? device_session.xmpp_account : ''
        unpair_session = db_conn.db_unpair_session_insert({device_id: device_id})
        ddns_session = db_conn.db_ddns_session_access({device_id: device_id})
        full_domain = !ddns_session.nil? ? ddns_session.full_domain : ''
        
        info = {xmpp_account: xmpp_account + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: unpair_session.id,
                full_domain: full_domain
                }
        
        XMPPController.send_request(KUNPAIR_ASK_REQUEST, info) if !device_session.nil? && !ddns_session.nil?
      }
      unpairThread.abort_on_exception = FALSE
      
    when 'upnp_submit' then
      puts 'Get SQS Upnp message submit %s' % data
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
      puts 'Get SQS Upnp message query %s' % data
      
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
      puts 'Get SQS DDNS message query %s' % data
      
      ddnsQueryThread = Thread.new{
        session_id = data[:session_id]
        ddns_session = db_conn.db_ddns_session_access({id: session_id})
        xmpp_account = db_conn.db_retreive_xmpp_account_by_ddns_session_id(session_id)
        device_session = db_conn.db_device_session_access({xmpp_account: xmpp_account})
        
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id],
                ip: !device_session.nil? ? device_session.ip : '',
                full_domain: !ddns_session.nil? ? ddns_session.full_domain : ''}
        
        XMPPController.send_request(KDDNS_SETTING_REQUEST, info) if !xmpp_account.nil? && !ddns_session.nil? && !device_session.nil?
      }
      ddnsQueryThread.abort_on_exception = TRUE
  end
}
