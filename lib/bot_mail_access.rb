#!/usr/bin/env ruby

require_relative 'bot_mail_content_template'
require 'aws-sdk'
require 'yaml'

MAIL_CONFIG_FILE = '../config/bot_mail_config.yml'

class BotMailAccess
  
  def initialize
    
    @ses_conn = nil
    @ses_token = nil
    
    config_file = File.join(File.dirname(__FILE__), MAIL_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    @ses_conn = self.mail_connection(config)
  end
  
  def mail_connection(config)
    account = {:access_key_id => config['access_key_id'],
               :secret_access_key => config['secret_access_key'],
               :region => config['region']
              }
    ses = AWS::SimpleEmailService.new(account)
    ses.identities.verify(config['mail_domain'])
    return ses
  end
  
  def send_offline_mail(to=nil)
    return FALSE if to.nil?
    
    mail_content = {subject: OFFLINE_SUBJECT,
                    to: to,
                    from: FROM_ADDRESS,
                    subject_charset: 'UTF-8',
                    body_text: OFFLINE_MESSAGE,
                    body_text_charset: 'UTF-8'
                    }
    
    response = @ses_conn.send_email(mail_content)
    
    return response.error.nil? ? TRUE : FALSE
  end
  
  def send_online_mail(to=nil)
    return FALSE if to.nil?
    
    mail_content = {subject: ONLINE_SUBJECT,
                    to: to,
                    from: FROM_ADDRESS,
                    subject_charset: 'UTF-8',
                    body_text: ONLINE_MESSAGE,
                    body_text_charset: 'UTF-8'
                    }
    
    response = @ses_conn.send_email(mail_content)
    
    return response.error.nil? ? TRUE : FALSE
  end
end