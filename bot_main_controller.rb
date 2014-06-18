#!/usr/bin/env ruby

require './bot_db_access'
require './bot_queue_access'
require './bot_pair_controller'

listenerThread = Thread.new {
  puts 'Listener running'
  PairListenController.new
  PairListenController.run
}
listenerThread.abort_on_exception = TRUE

senderThread = Thread.new {
    puts 'Sender running'
    PairSenderController.new
    PairSenderController.run
}
senderThread.abort_on_exception = TRUE

sqs = BotQueueAccess.new
sqs.sqs_listen{
  |job, data|
  
  puts 'Get SQS message'
  
  case job
    when 'pair' then
      puts 'Get SQS Pair message'
      Thread.new{
        PairSenderController.send_request('job1@10.1.1.110', 12)
      }
    
    when 'upnp' then
    when 'ddns' then  
  end
}