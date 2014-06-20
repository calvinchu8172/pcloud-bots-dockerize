#!/usr/bin/env ruby

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_pair_controller'
require 'rexml/document'

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