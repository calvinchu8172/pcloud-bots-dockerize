#!/usr/bin/env ruby

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_pair_controller'
require 'rexml/document'

XMPP_SERVER_DOMAIN = '@xmpp.pcloud.ecoworkinc.com'
XMPP_RESOURCE_ID = '/device'

jobThread = Thread.new {
    puts 'Pair controll running'
    PairController.new
    PairController.run
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

sqs = BotQueueAccess.new
sqs.sqs_listen{
  |job, data|
  
  puts 'Get SQS message'
  
  case job
    when 'pair' then
      puts 'Get SQS Pair message'
      pairThread = Thread.new{
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_pair_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id]}
        
        PairController.send_request(KPAIR_START_REQUEST, info) if !xmpp_account.nil?
      }
      pairThread.abort_on_exception = FALSE
    when 'unpair' then
      
    when 'upnp_submit' then
      puts 'Get SQS Upnp message submit'
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
        PairController.send_request(KUPNP_SETTING_REQUEST, info) if !xmpp_account.nil?
      }
      upnpSubmitThread.abort_on_exception = FALSE
      
    when 'upnp_query' then
      puts 'Get SQS Upnp message query'
      
      upnpQueryThread = Thread.new{
        session_id = data[:session_id]
        xmpp_account = db_conn.db_retreive_xmpp_account_by_upnp_session_id(session_id)
        info = {xmpp_account: xmpp_account.to_s + XMPP_SERVER_DOMAIN + XMPP_RESOURCE_ID,
                session_id: data[:session_id]}
        
        PairController.send_request(KUPNP_ASK_REQUEST, info) if !xmpp_account.nil?
      }
      upnpQueryThread.abort_on_exception = FALSE
      
    when 'ddns' then
  end
}
