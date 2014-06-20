#!/usr/bin/env ruby

require 'aws-sdk'
require 'json'
require 'yaml'

SQS_CONFIG_FILE = 'bot_queue_config.yml'

class BotQueueAccess
  
  def initialize
    @Queue = nil
    
    config_file = File.join(File.dirname(__FILE__), SQS_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    @Queue = self.sqs_connection(config)
  end
  
  def sqs_connection(config)
    account = {:access_key_id => config['access_key_id'],
               :secret_access_key => config['secret_access_key']
              }
    
    sqs = AWS::SQS.new(account)
    return sqs.queues.named(config['sqs_queue_name'])
  end
  
  def sqs_listen
    @Queue.poll do |message|
      msg = JSON.parse(message.body)
      if msg["job"] == "pair" && block_given? then
        job = msg["job"]
        data = {session_id: msg["session_id"]}
        yield(job, data)
      
      elsif msg["job"] == "upnp" && block_given? then
        job = msg["job"]
        data = {}
        yield(job, data)
      
      elsif msg["job"] == "ddns" && block_given? then
        job = msg["job"]
        data = {}
        yield(job, data)
        
      else
        puts 'Data type non JSON'
      end
      message.delete
    end
  end
  
#===================== Unuse methods =====================
#=========================================================
  def sqs_receive
  end
end