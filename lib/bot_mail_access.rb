#!/usr/bin/env ruby

require_relative 'bot_mail_content_template'
require 'aws-sdk-v1'
require 'yaml'
require 'net/smtp'

MAIL_CONFIG_FILE = '../config/bot_mail_config.yml'

class BotMailAccessSMTP
  def initialize
    @smtp = nil
    @config = nil

    config_file = File.join(File.dirname(__FILE__), MAIL_CONFIG_FILE)
    config = YAML.load(File.read(config_file))

    @config = config
    @smtp = self.mail_connection(config)
  end

  def mail_connection(config)
    smtp = Net::SMTP.new(config['smtp_host'], config['smtp_port'])
    smtp.enable_tls
    return smtp
  end

  def send_offline_mail(to=nil)
    return FALSE if to.nil? || to.empty?

    bcc = nil
    bcc = to.join(',')
    mail_content = MAIL_CONTENT % [FROM_ADDRESS, bcc, OFFLINE_SUBJECT, OFFLINE_MESSAGE]

    begin
      if !@smtp.started? then
        @smtp.start(@config['mail_domain'],
                  @config['smtp_user'],
                  @config['smtp_password'], :plain)
      end
      response = @smtp.send_message mail_content, FROM_ADDRESS, to
      @smtp.finish
      return response.success? ? TRUE : FALSE
    rescue Exception => error
      puts error
      return FALSE
    end
  end

  def send_online_mail(to=nil)
    return FALSE if to.nil? || to.empty?

    bcc = nil
    bcc = to.join(',')
    mail_content = MAIL_CONTENT % [FROM_ADDRESS, bcc, ONLINE_SUBJECT, ONLINE_MESSAGE]

    begin
      if !@smtp.started? then
        @smtp.start(@config['mail_domain'],
                  @config['smtp_user'],
                  @config['smtp_password'], :plain)
      end
      response = @smtp.send_message mail_content, FROM_ADDRESS, to
      @smtp.finish
      return response.success? ? TRUE : FALSE
    rescue Exception => error
      puts error
      return FALSE
    end
  end
end

class BotMailAccess

  def initialize

    @ses_conn = nil
    @ses_token = nil

    config_file = File.join(File.dirname(__FILE__), MAIL_CONFIG_FILE)
    config = YAML.load(File.read(config_file))

    @ses_conn = self.mail_connection(config)
  end

  def mail_connection(config)
    ses = AWS::SimpleEmailService.new(:region => config['region'])
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
