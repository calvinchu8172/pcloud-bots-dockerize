#!/usr/bin/env ruby

require 'aws-sdk'
require 'json'
require 'yaml'

SQS_QUEUE_NAME = 'personal_cloud_queue'
SQS_CONFIG_FILE = 'bot_queue_config.yml'

class BotQueueAccess
  
  def initialize
    @Queue = nil
    
    config_file = File.join(File.dirname(__FILE__), SQS_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    @Queue = self.sqs_connection(config)
  end
  
  def sqs_connection(config)
    sqs = AWS::SQS.new(config)    
    return sqs.queues.named(SQS_QUEUE_NAME)
  end
  
  def sqs_listen
    @Queue.poll do |message|
      msg = JSON.parse(message.body)
      if msg["job"] == "pair" && block_given? then
        job = msg["job"]
        data = {session_id: msg["session_id"], user_id: msg["user_id"], device_id: msg["device_id"]}
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