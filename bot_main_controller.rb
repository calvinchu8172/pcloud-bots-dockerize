#!/usr/bin/env ruby

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_xmpp_controller'

XMPP_SERVER_DOMAIN = '@xmpp.pcloud.ecoworkinc.com'
XMPP_RESOURCE_ID = '/device'

jobThread = Thread.new {
    puts 'Pair controll running'
    XMPPController.new
    XMPPController.run
}
jobThread.abort_on_exception = TRUE

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

sleep(5)

sqs = BotQueueAccess.new
sqs.sqs_listen{
  |job, data|
  
  case job
    when 'pair' then
      puts 'Get SQS Pair message %s' % data
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
        
        info = {xmpp_account: xmpp_account + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: unpair_session.id}
        
        XMPPController.send_request(KUNPAIR_ASK_REQUEST, info) if !device_session.nil?
      }
      unpairThread.abort_on_exception = FALSE
      
    when 'upnp_submit' then
      puts 'Get SQS Upnp message submit %s' % data
      upnpSubmitThread = Thread.new {
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_upnp_session_id(session_id)
        service_list = db_conn.db_upnp_session_access({id: session_id}).service_list
        
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
                session_id: data[:session_id],
                field_item: field_item}
        XMPPController.send_request(KUPNP_SETTING_REQUEST, info) if !xmpp_account.nil?
      }
      upnpSubmitThread.abort_on_exception = FALSE
      
    when 'upnp_query' then
      puts 'Get SQS Upnp message query %s' % data
      
      upnpQueryThread = Thread.new{
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_upnp_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id]}
        
        XMPPController.send_request(KUPNP_ASK_REQUEST, info) if !xmpp_account.nil?
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