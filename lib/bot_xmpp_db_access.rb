#!/usr/bin/env ruby

require_relative 'bot_unit'
require 'rubygems'
require 'active_record'
require 'yaml'
require 'ipaddr'

XMPP_DB_CONFIG_FILE = '../config/bot_xmpp_db_config.yml'

class XMPPDatabaseModel < ActiveRecord::Base
  self.abstract_class = true
end

class XMPP_User < XMPPDatabaseModel
  self.table_name = "users"
end

class BotXmppDBAccess

  def initialize
    @Client = nil
    config_file = File.join(File.dirname(__FILE__), XMPP_DB_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    @Client = self.db_connection(config)
  end

  def db_connection(config = {})
    return nil if config.empty?

    db_host = config['db_host']
    #db_socket = config['db_socket']
    db_name = config['db_name']
    db_userid = config['db_userid']
    db_userpw = config['db_userpw']
    db_pool = config['db_pool']
    #db_reaping_frequency = config['db_reaping_frequency']

    connect = XMPPDatabaseModel.establish_connection(:adapter  => 'mysql2',
                                            :database => db_name,
                                            :username => db_userid,
                                            :password => db_userpw,
                                            :host     => db_host,
                                            #:socket   => db_socket,
                                            :reconnect => TRUE,
                                            :pool     => db_pool,
                                            #:reaping_frequency => db_reaping_frequency
                                            )
    return XMPPDatabaseModel.connection_pool.checkout
  end

  def close
      XMPPDatabaseModel.connection_pool.checkin(@Client) if !@Client.nil?
  end


#=============== User Methods ===============
#===============================================

  def db_reset_password(username = nil)
    return nil if username.nil?

    # Ref rest api format
    origin = [('a'..'z'), ('A'..'Z')].map { |i| i.to_a }.flatten
    new_password = (0...10).map { origin[rand(origin.length)] }.join

    XMPP_User.find_by(username: username).update(password: new_password)

    return new_password
  end


end