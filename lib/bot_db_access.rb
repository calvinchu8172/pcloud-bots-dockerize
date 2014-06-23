#!/usr/bin/env ruby

require 'rubygems'
require 'active_record'
require 'yaml'

DB_CONFIG_FILE = '../config/bot_db_config.yml'

class Pairing < ActiveRecord::Base
  self.table_name = "pairings"
end

class PairingSession < ActiveRecord::Base
  self.table_name = "pairing_sessions"
end

class Devices < ActiveRecord::Base
  self.table_name = "devices"
end

class DeviceSession < ActiveRecord::Base
  self.table_name = "device_sessions"
end

class UpnpSession < ActiveRecord::Base
  self.table_name = "upnp_sessions"
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
    db_name = config['db_name']
    db_userid = config['db_userid']
    db_userpw = config['db_userpw']
    db_pool = config['db_pool']
    db_reaping_frequency = config['db_reaping_frequency']
    
    connect = ActiveRecord::Base.establish_connection(:adapter  => 'mysql',
                                            :database => db_name,
                                            :username => db_userid,
                                            :password => db_userpw,
                                            :host     => db_host,
                                            :pool     => db_pool,
                                            :reaping_frequency => db_reaping_frequency
                                            )
    return connect
  end
  
  def close
    ActiveRecord::Base.remove_connection(@Client) if !@Client.nil?
  end
  
#=============== Pairing Methods ===============
#===============================================

  def db_pairing_access(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = Pairing.where(:user_id => user_id, :device_id => device_id).first
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_pairing_insert(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = self.db_pairing_access(user_id, device_id)
    if rows.nil? then
      isSuccess = Pairing.create(:user_id => user_id, :device_id => device_id)
      return self.db_pairing_access(user_id, device_id) if isSuccess
    else
      return rows
    end
  end
  
  def db_pairing_update(id = nil, userid = nil, deviceid = nil)
    return FALSE if id.nil? || userid.nil? || deviceid.nil?
    
    result = Pairing.find_by(:id => id)
    result.update(user_id: userid)
    result.update(device_id: deviceid)
    
    return result.nil? ? TRUE : FALSE
  end
  
  def db_pairing_delete(id = nil)
    return FALSE if id.nil?
    
    result = Pairing.find_by(:id => id)
    result.destroy
    return result.nil? ? TRUE : FALSE
  end
  
  def db_pairing_session_access(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = PairingSession.where(:user_id => user_id, :device_id => device_id).first
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_pairing_session_access_by_id(id = nil)
    return nil if id.nil?
    result = PairingSession.find_by(:id => id)
    return result
  end
  
  def db_pairing_session_insert(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = self.db_pairing_session_access(user_id, device_id)
    if rows.nil? then
      isSuccess = PairingSession.create(:user_id => user_id, :device_id => device_id)
      return self.db_pairing_session_access(user_id, device_id) if isSuccess
    else
      return rows
    end
  end
  
  def db_pairing_session_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:status))
    
    result = PairingSession.find_by(:id => data[:id])
    result.update(user_id: data[:user_id]) if data.has_key?(:user_id)
    result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
    result.update(status: data[:status]) if data.has_key?(:status)
    result.update(updated_at: DateTime.now)
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_pairing_session_delete(id = nil)
    return nil if id.nil?
    
    result = PairingSession.find_by(:id => id)
    result.destroy
    return !result.nil? ? TRUE : FALSE
  end

  def db_pairing_session_access_timeout
    rows = PairingSession.where(["(`status` = 0 OR `status` = 1) AND `expire_at` < ?", DateTime.now])
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
#=============== Device Methods ===============
#===============================================  
  
  def db_device_access(data={})
    return nil if data.empty? || !data.has_key?(:serial_number) || !data.has_key?(:mac_address) || !data.has_key?(:model_name) || !data.has_key?(:firmware_version)
    
    rows = Devices.where(:serial_number => data[:serial_number],
                         :mac_address => data[:mac_address],
                         :model_name => data[:model_name],
                         :firmware_version => data[:firmware_version]).first
    
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
    result.update(serial_number: data[:serial_number]) if data.has_key?(:serial_number)
    result.update(mac_address: data[:mac_address]) if data.has_key?(:mac_address)
    result.update(model_name: data[:model_name]) if data.has_key?(:model_name)
    result.update(firmware_version: data[:firmware_version]) if data.has_key?(:firmware_version)
    result.update(updated_at: DateTime.now)
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_device_delete(id = nil)
    return nil if id.nil?
    
    result = Devices.find_by(:id => id)
    result.destroy
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_device_session_access(device_id = nil)
    return nil if device_id.nil?
    
    rows = DeviceSession.where(:device_id => device_id).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_device_session_access_by_device_id(device_id = nil)
    return nil if device_id.nil?
    result = DeviceSession.find_by(:device_id => device_id)
    return result
  end
  
  def db_device_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || !data.has_key?(:ip) || !data.has_key?(:xmpp_account) || !data.has_key?(:password)

    rows = self.db_device_session_access(data[:device_id])
    if rows.nil? then
      isSuccess = DeviceSession.create(:device_id => data[:device_id],
                                       :ip => data[:ip],
                                       :xmpp_account => data[:xmpp_account],
                                       :password => data[:password]
                                       )
      
      return self.db_device_session_access(data[:device_id]) if isSuccess
    else
      return rows
    end
  end
  
  def db_device_session_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:device_id) && !data.has_key?(:ip) && !data.has_key?(:xmpp_account) && !data.has_key?(:password))
    
    result = DeviceSession.find_by(:id => data[:id])
    result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
    result.update(ip: data[:ip]) if data.has_key?(:ip)
    result.update(xmpp_account: data[:xmpp_account]) if data.has_key?(:xmpp_account)
    result.update(password: data[:password]) if data.has_key?(:password)
    result.update(updated_at: DateTime.now)
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_device_session_delete(id = nil)
    return nil if id.nil?
    
    result = DeviceSession.find_by(:id => id)
    result.destroy
    
    return !result.nil? ? TRUE : FALSE
  end

#=============== Upnp Methods ===============
#===============================================
  def db_upnp_session_access(data={})
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:status) && !data.has_key?(:service_list))
    rows = UpnpSession.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end

  def db_upnp_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:user_id) || !data.has_key?(:device_id) || !data.has_key?(:status) || !data.has_key?(:service_list)
    
    rows = self.db_upnp_session_access(data)
    if rows.nil? then
      isSuccess = UpnpSession.create(data)
      return self.db_upnp_session_access(data) if isSuccess
    else
      return rows
    end
  end

  def db_upnp_session_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:status) && !data.has_key?(:service_list))
    
    result = UpnpSession.find_by(:id => data[:id])
    result.update(user_id: data[:user_id]) if data.has_key?(:user_id)
    result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
    result.update(status: data[:status]) if data.has_key?(:status)
    result.update(service_list: data[:service_list]) if data.has_key?(:service_list)
    result.update(updated_at: DateTime.now)
    
    return !result.nil? ? TRUE : FALSE
  end

  def db_upnp_session_delete(id = nil)
    return nil if id.nil?
    
    result = UpnpSession.find_by(:id => id)
    result.destroy
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_retreive_xmpp_account_by_upnp_session_id(id = nil)
    return nil if id.nil?
    
    sql_string = "SELECT `device_sessions`.`xmpp_account` AS `xmpp_account` FROM `device_sessions`, `upnp_sessions` WHERE \
                 `upnp_sessions`.`id`=%d AND \
                 `upnp_sessions`.`device_id`=`device_sessions`.`device_id`" % id
    rows = UpnpSession.find_by_sql(sql_string).first
    
    if !rows.nil? && rows.respond_to?(:xmpp_account) then
      return rows.xmpp_account
    else
      return nil
    end
  end
end