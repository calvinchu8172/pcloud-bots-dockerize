#!/usr/bin/env ruby

require_relative 'bot_unit'
require 'rubygems'
require 'active_record'
require 'yaml'
require 'ipaddr'

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
  attr_accessor :full_domain

  def ip_address
    IPAddr.new(read_attribute(:ip_address).to_i(16), Socket::AF_INET).to_s
  end

  def full_domain
    domain = Domain.find(self.domain_id)
    self.hostname + '.' + domain.domain_name
  end

  def full_domain=(str)
    self.hostname = find_hostname(str)
    domain = find_domainname(str)
    self.domain_id = Domain.find_by_domain_name(domain).id
  end

  def ip_address=(ip)
    write_attribute(:ip_address, IPAddr.new(ip).to_i.to_s(16).rjust(8, "0"))
  end
end

class Domain < ActiveRecord::Base
  self.table_name = "domains"
end

class Product < ActiveRecord::Base
  self.table_name = "products"
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

    return ActiveRecord::Base.connection_pool.checkout
  end
  
  def close
     ActiveRecord::Base.connection_pool.checkin(@Client) if !@Client.nil?
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
      isSuccess = Pairing.create(:user_id => user_id, :device_id => device_id, :ownership => 0)
      return self.db_pairing_access({user_id: user_id, device_id: device_id}) if isSuccess
    else
      return rows
    end
  end
  
  def db_pairing_update(data={})
    return FALSE if data.empty? || !data.has_key?(:id) || (!data.has_key?(:user_id) && !data.has_key?(:device_id))
    
    result = Pairing.find_by(:id => data[:id])
    if !result.nil? then
      result.update(user_id: data[:user_id]) if data.has_key?(:user_id)
      result.update(device_id: data[:device_id]) if data.has_key?(:device_id)
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
    return nil if data.empty? || (!data.has_key?(:id) && !data.has_key?(:serial_number) && !data.has_key?(:mac_address) && !data.has_key?(:product_id) && !data.has_key?(:firmware_version))
    
    rows = Devices.where(data).first
    
    if !rows.nil? then
      return rows
    else
      return nil
    end
  end
  
  def db_device_insert(data={})
    return nil if data.empty? || !data.has_key?(:serial_number) || !data.has_key?(:mac_address) || !data.has_key?(:product_id) || !data.has_key?(:firmware_version)

    rows = self.db_device_access(data)
    if rows.nil? then
      isSuccess = Devices.create(:serial_number => data[:serial_number],
                                 :mac_address => data[:mac_address],
                                 :product_id => data[:product_id],
                                 :firmware_version => data[:firmware_version])
      
      return self.db_device_access(data) if isSuccess
    else
      return rows
    end
  end
  
  def db_device_update(data={})
    return nil if data.empty? || !data.has_key?(:id) || (!data.has_key?(:serial_number) && !data.has_key?(:mac_address) && !data.has_key?(:product_id) && !data.has_key?(:firmware_version))
    
    result = Devices.find_by(:id => data[:id])
    
    if !result.nil? then
      result.update(serial_number: data[:serial_number]) if data.has_key?(:serial_number)
      result.update(mac_address: data[:mac_address]) if data.has_key?(:mac_address)
      result.update(product_id: data[:product_id]) if data.has_key?(:product_id)
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
    
    where_data = data.clone

    if data.has_key?(:full_domain) then
      full_domain = where_data[:full_domain]
      host_name = find_hostname(full_domain)
      domain_name = find_domainname(full_domain)
      domain = Domain.find_by_domain_name(domain_name)
      domain_id = domain.id
      where_data[:hostname] = host_name
      where_data[:domain_id] = domain_id
      where_data.delete(:full_domain)
    end

    if where_data.has_key?(:ip_address) then
      where_data[:ip_address] = IPAddr.new(where_data[:ip_address]).to_i.to_s(16).rjust(8, "0")
    end

    rows = DDNS.where(where_data).first
    
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
end
