#!/usr/bin/env ruby

require 'rubygems'
require 'active_record'

DB_HOST = "localhost"
DB_NAME = "personal_cloud"
DB_USERID = "root"
DB_USERPW = "12345"

class Pairing < ActiveRecord::Base
  self.table_name = "pairing"
end

class PairingSession < ActiveRecord::Base
  self.table_name = "pairing_session"
end

class Devices < ActiveRecord::Base
  self.table_name = "devices"
end

class DeviceSession < ActiveRecord::Base
  self.table_name = "device_sessions"
end

class BotDBAccess
  
  def initialize
    @Client = nil
    config = {db_host:DB_HOST,
              db_name:DB_NAME,
              db_userid:DB_USERID,
              db_userpw:DB_USERPW}
    
    self.db_connection(config)
  end
  
  def db_connection(config = {})
    return nil if config.empty?
    
    db_host = config[:db_host]
    db_name = config[:db_name]
    db_userid = config[:db_userid]
    db_userpw = config[:db_userpw]
    
    ActiveRecord::Base.establish_connection(:adapter  => 'mysql',
                                            :database => db_name,
                                            :username => db_userid,
                                            :password => db_userpw,
                                            :host     => db_host)
  end
  
  def close
    @Client.close if !@Client.nil?
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
    return nil if data.empty? || !data.has_key?(:id) || !data.has_key?(:user_id) || !data.has_key?(:device_id) || !data.has_key?(:status)
    
    result = PairingSession.find_by(:id => data[:id])
    result.update(user_id: data[:user_id])
    result.update(device_id: data[:device_id])
    result.update(status: data[:status])
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_pairing_session_delete(id = nil)
    return nil if id.nil?
    
    result = PairingSession.find_by(:id => id)
    result.destroy
    return !result.nil? ? TRUE : FALSE
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
    return nil if data.empty? || !data.has_key?(:id) || !data.has_key?(:serial_number) || !data.has_key?(:mac_address) || !data.has_key?(:model_name) || !data.has_key?(:firmware_version)
    
    result = Devices.find_by(:id => data[:id])
    result.update(serial_number: data[:serial_number])
    result.update(mac_address: data[:mac_address])
    result.update(model_name: data[:model_name])
    result.update(firmware_version: data[:firmware_version])
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
    return nil if data.empty? || !data.has_key?(:id) || !data.has_key?(:device_id) || !data.has_key?(:ip) || !data.has_key?(:xmpp_account) || !data.has_key?(:password)
    
    result = DeviceSession.find_by(:id => data[:id])
    result.update(device_id: data[:device_id])
    result.update(ip: data[:ip])
    result.update(xmpp_account: data[:xmpp_account])
    result.update(password: data[:password])
    result.update(updated_at: DateTime.now)
    
    return !result.nil? ? TRUE : FALSE
  end
  
  def db_device_session_delete(id = nil)
    return nil if id.nil?
    
    result = DeviceSession.find_by(:id => id)
    result.destroy
    
    return !result.nil? ? TRUE : FALSE
  end
end