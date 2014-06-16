#!/usr/bin/env ruby

require 'mysql2'

DB_HOST = "localhost"
DB_NAME = "personal_cloud"
DB_USERID = "root"
DB_USERPW = "12345"

class BotDBAccess
  
  def initialize
    @Client = nil
    config = {db_host:DB_HOST,
              db_name:DB_NAME,
              db_userid:DB_USERID,
              db_userpw:DB_USERPW}
    
    @Client = self.db_connection(config)
  end
  
  def db_connection(config = {})
    return nil if config.empty?
    
    db_host = config[:db_host]
    db_name = config[:db_name]
    db_userid = config[:db_userid]
    db_userpw = config[:db_userpw]
    
    conn = Mysql2::Client.new(:host => db_host, :username => db_userid, :password => db_userpw, :database => db_name)
    return conn
  end
  
  def close
    @Client.close if !@Client.nil?
  end
  
#=============== Pairing Methods ===============

  def db_pairing_access(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = @Client.query("SELECT * FROM `pairing` WHERE `user_id`='#{user_id}' AND `device_id`=#{device_id} LIMIT 1")
    
    if rows.count > 0 then
      data = nil
      rows.each do |result|
        data = result
      end
      return data
    else
      return nil
    end
  end
  
  def db_pairing_insert(user_id = nil, device_id = nil)
    return nil if user_id.nil? || device_id.nil?
    
    rows = self.db_pairing_access(user_id, device_id)
    if rows.nil? then
      result = @Client.query("INSERT INTO `pairing` (`user_id`, `device_id`) VALUES ('#{user_id}', #{device_id})")
      return result
    else
      return rows
    end
  end
  
  def db_pairing_update(id = nil, user_id = nil, device_id = nil)
    return FALSE if id.nil? || user_id.nil? || device_id.nil?
    result = @Client.query("UPDATE `pairing` SET `device_id`=#{device_id} WHERE `user_id`='#{user_id}' AND `id`=#{id}")
    return result.nil? ? TRUE : FALSE
  end
  
  def db_pairing_delete(id = nil, user_id = nil, device_id = nil)
    return FALSE if id.nil? || user_id.nil? || device_id.nil?
    result = @Client.query("DELETE FROM `pairing` WHERE `id`=#{id} AND `user_id`='#{user_id}' AND `device_id`=#{device_id}")
    return result.nil? ? TRUE : FALSE
  end
end
