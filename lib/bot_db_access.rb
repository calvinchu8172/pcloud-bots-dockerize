#!/usr/bin/env ruby

require 'rubygems'
require 'active_record'
require 'yaml'

DB_CONFIG_FILE = '../config/bot_db_config.yml'

class Pairing < ActiveRecord::Base
  self.table_name = "pairings"
end

class Devices < ActiveRecord::Base
  self.table_name = "devices"
end

class User < ActiveRecord::Base
  self.table_name = "users"
end

class DDNS < ActiveRecord::Base
  self.table_name = "ddns"
end

class DDNSSession < ActiveRecord::Base
  self.table_name = "ddns_sessions"
end

class DDNSRetrySession < ActiveRecord::Base
  self.table_name = "ddns_retry_sessions"
end

class BotDBAccess
  
  def initialize
    @Client = nil
    config_file = File.join(File.dirname(__FILE__), DB_CONFIG_FILE)
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
    
    connect = ActiveRecord::Base.establish_connection(:adapter  => 'mysql2',
                                            :database => db_name,
                                            :username => db_userid,
                                            :password => db_userpw,
                                            :host     => db_host,
                                            #:socket   => db_socket,
                                            :reconnect => TRUE,
                                            :pool     => db_pool,
                                            #:reaping_frequency => db_reaping_frequency
                                            )
    return connect
  end
  
  def close
    ActiveRecord::Base.remove_connection(@Client) if !@Client.nil?
  end

#=============== User Methods ===============
#===============================================

  def db_user_access(id = nil)
    return nil if id.nil?
    
    data = {:id => id}
    
    rows = User.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end

#=============== Pairing Methods ===============
#===============================================

  def db_pairing_access(data={})
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:user_id) && !data.has_key?(:device_id))
    
    rows = Pairing.where(data).first
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_pairing_insert(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = self.db_pairing_access({user_id: user_id, device_id: device_id})
    if rows.nil? then
      isSuccess = Pairing.create(:user_id => user_id, :device_id => device_id)
      return self.db_pairing_access({user_id: user_id, device_id: device_id}) if isSuccess
    else
      return rows
    end
  end
  
  def db_pairing_update(data={})
    return FALSE if data.empty? || !data.has_key?(:id) || (!data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:enabled))
    
    result = Pairing.find_by(:id => data[:id])
    if !result.nil? then
      result.update(user_id: data[:user_id]) if data.has_key?(:user_id)
      result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
      result.update(enabled: data[:enabled]) if data.has_key?(:enabled)
      result.update(updated_at: DateTime.now)
    end
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_pairing_delete(id = nil)
    return FALSE if id.nil?
    
    result = Pairing.find_by(:id => id)
    result.destroy if !result.nil?
    return !result.nil? ? TRUE : FALSE
  end
#=============== Device Methods ===============
#===============================================  
  
  def db_device_access(data={})
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:serial_number) && !data.has_key?(:mac_address) && !data.has_key?(:model_name) && !data.has_key?(:firmware_version))
    
    rows = Devices.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_device_insert(data={})
    return nil if data.empty? || !data.has_key?(:serial_number) || !data.has_key?(:mac_address) || !data.has_key?(:model_name) || !data.has_key?(:firmware_version)

    rows = self.db_device_access(data)
    if rows.nil? then
      isSuccess = Devices.create(:serial_number => data[:serial_number],
                                 :mac_address => data[:mac_address],
                                 :model_name => data[:model_name],
                                 :firmware_version => data[:firmware_version])
      
      return self.db_device_access(data) if isSuccess
    else
      return rows
    end
  end
  
  def db_device_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:serial_number) && !data.has_key?(:mac_address) && !data.has_key?(:model_name) && !data.has_key?(:firmware_version))
    
    result = Devices.find_by(:id => data[:id])
    
    if !result.nil? then
      result.update(serial_number: data[:serial_number]) if data.has_key?(:serial_number)
      result.update(mac_address: data[:mac_address]) if data.has_key?(:mac_address)
      result.update(model_name: data[:model_name]) if data.has_key?(:model_name)
      result.update(firmware_version: data[:firmware_version]) if data.has_key?(:firmware_version)
      result.update(updated_at: DateTime.now)
    end
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_device_delete(id = nil)
    return nil if id.nil?
    
    result = Devices.find_by(:id => id)
    result.destroy if !result.nil?
    
    return !result.nil? ? TRUE : FALSE
  end

#=============== DDNS Methods ===============
#===============================================

  def db_ddns_access(data={})
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:device_id) && !data.has_key?(:ip_address) && !data.has_key?(:full_domain))
    
    rows = DDNS.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_ddns_insert(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || !data.has_key?(:ip_address) || !data.has_key?(:full_domain)
    
    rows = self.db_ddns_access(data)
    
    if rows.nil? then
      isSuccess = DDNS.create(data)
      return self.db_ddns_access(data) if isSuccess
    else
      return rows
    end
  end

  def db_ddns_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:device_id) && !data.has_key?(:ip_address) && !data.has_key?(:full_domain))
    
    result = DDNS.find_by(:id => data[:id])
    if !result.nil? then
      result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
      result.update(ip_address: data[:ip_address]) if data.has_key?(:ip_address)
      result.update(full_domain: data[:full_domain]) if data.has_key?(:full_domain)
      result.update(updated_at: DateTime.now)
    end
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_ddns_delete(id=nil)
    return nil if id.nil?
    
    result = DDNS.find_by(:id => id)
    result.destroy if !result.nil?
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_ddns_session_access(data={})
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:device_id) && !data.has_key?(:full_domain) && !data.has_key?(:status))
    
    rows = DDNSSession.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_ddns_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || !data.has_key?(:full_domain) || !data.has_key?(:status)
    
    rows = self.db_ddns_session_access(data)
    
    if rows.nil? then
      isSuccess = DDNSSession.create(data)
      return self.db_ddns_session_access(data) if isSuccess
    else
      return rows
    end
  end
  
  def db_ddns_session_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:device_id) && !data.has_key?(:full_domain) && !data.has_key?(:status))
    
    result = DDNSSession.find_by(:id => data[:id])
    if !result.nil? then
      result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
      result.update(full_domain: data[:full_domain]) if data.has_key?(:full_domain)
      result.update(status: data[:status]) if data.has_key?(:status)
      result.update(updated_at: DateTime.now)
    end
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_ddns_session_delete(id=nil)
    return nil if id.nil?
    
    result = DDNSSession.find_by(:id => id)
    result.destroy if !result.nil?
    
    return !result.nil? ? TRUE : FALSE
  end
  
#============== User Info Methods ==============
#===============================================
  def db_retrive_user_local_by_device_id(device_id = nil)
    return nil if device_id.nil?
    
    sql_string = "SELECT `users`.`language` AS `language` FROM `pairings`, `users` WHERE \
                 `pairings`.`device_id`=%d AND \
                 `pairings`.`user_id`=`users`.`id`" % device_id
    rows = Pairing.find_by_sql(sql_string).first
    
    if !rows.nil? && rows.respond_to?(:language) then
      return rows.language
    else
      return nil
    end
  end
  
  def db_retrive_user_email_by_ddns_session_id(id=nil)
    return nil if id.nil?
    
    sql_string = "SELECT `users`.`email` AS `email` FROM `pairings`, `ddns_sessions`, `users` WHERE \
                 `ddns_sessions`.`id`=%d AND \
                 `ddns_sessions`.`device_id`=`pairings`.`device_id` AND \
                 `users`.`id`=`pairings`.`user_id`" % id
    
    rows = DDNSSession.find_by_sql(sql_string).first
    
    if !rows.nil? && rows.respond_to?(:email) then
      return rows.email
    else
      return nil
    end
  end

  def db_retrive_user_email_by_device_id(device_id=nil)
    return nil if device_id.nil?

    sql_string = "SELECT `users`.`email` AS `email` FROM `users`, `pairings` WHERE `pairings`.`device_id`=%d \
                 AND `pairings`.`user_id`=`users`.`id`" % device_id
    rows = User.find_by_sql(sql_string).first

    if !rows.nil? && rows.respond_to?(:email) then
      return rows.email
    else
      return nil
    end
  end
#=============== DDNS Retry Methods ============
#===============================================
  def db_ddns_retry_session_access(data={})
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:device_id) && !data.has_key?(:full_domain))
    
    rows = DDNSRetrySession.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_ddns_retry_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || !data.has_key?(:full_domain)
    
    rows = self.db_ddns_retry_session_access(data)
    
    if rows.nil? then
      record = DDNSRetrySession.new(data)
      isSuccess = record.save
      
      return record if isSuccess
    else
      return rows
    end
  end
  
  def db_ddns_retry_session_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || !data.has_key?(:device_id) || !data.has_key?(:full_domain)
    
    result = DDNSRetrySession.find_by(:id => data[:id])
    if !result.nil? then
      result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
      result.update(full_domain: data[:full_domain]) if data.has_key?(:full_domain)
      result.update(updated_at: DateTime.now)
    end
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_ddns_retry_session_delete(id=nil)
    return nil if id.nil?
    
    result = DDNSRetrySession.find_by(:id => id)
    result.destroy if !result.nil?
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_retrive_retry_ddns
    data = DDNSRetrySession.limit(100).all
    if !data.nil? then
      return data
    else
      return nil
    end
  end
end
