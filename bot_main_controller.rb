#!/usr/bin/env ruby

require './bot_db_access'
require './bot_queue_access'
require './bot_pair_controller'
require 'rexml/document'

jobThread = Thread.new {
    puts 'Pair controll running'
    PairController.new
    PairController.run
}
jobThread.abort_on_exception = TRUE

db_conn = BotDBAccess.new

sqs = BotQueueAccess.new
sqs.sqs_listen{
  |job, data|
  
  puts 'Get SQS message'
  
  case job
    when 'pair' then
      puts 'Get SQS Pair message'
      Thread.new{
        session_id = data[:session_id]
        device = db_conn.db_device_session_access_by_id(session_id)
        info = {xmpp_account: device[:xmpp_account], session_id: data[:session_id]}
        PairController.send_request(KPAIR_START_REQUEST, info)
      }
    
    when 'upnp' then
    when 'ddns' then  
  end
}