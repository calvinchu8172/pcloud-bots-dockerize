#!/usr/bin/env ruby

require 'aws-sdk-v1'
require 'json'
require 'yaml'
require_relative './bot_unit'

SQS_CONFIG_FILE = '../config/bot_queue_config.yml'

class BotQueueAccess
  
  def initialize
    @Queue = nil
    
    config_file = File.join(File.dirname(__FILE__), SQS_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    @Queue = self.sqs_connection(config)
  end
  
  def sqs_connection(config)
    account = {:access_key_id => config['access_key_id'],
               :secret_access_key => config['secret_access_key'],
               :region => config['region']
              }
    
    sqs = AWS::SQS.new(account)
    return sqs.queues.named(config['sqs_queue_name'])
  end
  
  def sqs_listen
    @Queue.poll do |message|
      isValid = valid_json? message.body
      if isValid then
        msg = JSON.parse(message.body)
        if msg["job"] == "pairing" && block_given? then
          job = msg["job"]
          data = {device_id: msg["device_id"]}
          yield(job, data)

        elsif msg["job"] == "cancel" && block_given? then
          job = msg["job"]
          data = {title: msg["title"], tag: msg["tag"]}
          yield(job, data)

        elsif msg["job"] == "unpair" && block_given? then
          job = msg["job"]
          data = {device_id: msg["device_id"]}
          yield(job, data)

        elsif (msg["job"] == "upnp_query" || msg["job"] == "upnp_submit") && block_given? then
          job = msg["job"]
          data = {session_id: msg["session_id"]}
          yield(job, data)

        elsif msg["job"] == "ddns" && block_given? then
          job = msg["job"]
          data = {session_id: msg["session_id"]}
          yield(job, data)

        elsif msg["job"] == "create_permission" && block_given? then
          job = msg["job"]
          data = {invitation_id: msg["invitation_id"], user_email: msg["user_email"]}
          yield(job, data)

        else
          puts 'Data type non JSON'
        end
      end
      message.delete
    end
  end
  
#===================== Unuse methods =====================
#=========================================================
  def sqs_receive
  end
end
