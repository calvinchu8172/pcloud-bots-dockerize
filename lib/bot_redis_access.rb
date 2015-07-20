#!/usr/bin/env ruby

require 'rubygems'
require 'yaml'
require 'redis'
require 'json'
require_relative './bot_unit'

REDIS_CONFIG_FILE = '../config/bot_redis_config.yml'

DEVICE_SESSION_KEY = "device:%d:session"
PAIRING_SESSION_KEY = "device:%d:pairing_session"
UPNP_SESSION_KEY = "upnp:%d:session"
DDNS_SESSION_KEY = "ddns:%d:session"
UNPAIR_SESSION_KEY = "unpair:%d:session"
DDNS_SESSION_INDEX_KEY = "ddns:session:index"
DDNS_RETRY_SESSION_KEY = "ddns:retry_session"
DDNS_RETRY_LOCK_KEY = "ddns:retry_lock"
DDNS_RETRY_LOCL_EXPIRE_TIME = 20

DDNS_BATCH_SESSION_KEY = "ddns:batch_session"
DDNS_BATCH_LOCK_KEY = "ddns:batch_lock"
DDNS_BATCH_LOCK_EXPIRE_TIME = 20
DDNS_RESEND_SESSION_KEY = "ddns:%d:resend_session"
DDNS_RESEND_EXPIRE_TIME = 60

DEVICE_INFORMATION_KEY = "device:info:%d:session"

XMPP_SESSION_KEY = "xmpp:%s:session"

USER_PERMISSION_KEY = "invitation:%d:session"

LED_INDICATOR_SESSION_KEY = "device:indicator:%d:session"
PACKAGE_SESSION_KEY = "package:%d:session"

class BotRedisAccess

  def initialize
    @redis = nil
    config_file = File.join(File.dirname(__FILE__), REDIS_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    @redis = Redis.new(:host => config['rd_host'], :port => config['rd_port'], :db => config['rd_db'])
  end

#=============== Pairing Methods ===============
#===============================================
  def rd_pairing_session_access(device_id = nil)
    return nil if nil == device_id

    key = PAIRING_SESSION_KEY % device_id
    result = @redis.hgetall(key)
    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_pairing_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || (!data.has_key?(:user_id) && !data.has_key?(:status) && !data.has_key?(:error_code) && !data.has_key?(:expire_at))

    key = PAIRING_SESSION_KEY % data[:device_id]

    @redis.hset(key, "user_id", data[:user_id]) if data.has_key?(:user_id)
    @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
    @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)
    @redis.hset(key, "expire_at", data[:expire_at]) if data.has_key?(:expire_at)

    return @redis.hgetall(key)
  end

  def rd_pairing_session_update(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || (!data.has_key?(:user_id) && !data.has_key?(:status) && !data.has_key?(:error_code) && !data.has_key?(:expire_at))

    isExist = self.rd_pairing_session_access(data[:device_id])
    if isExist then
      key = PAIRING_SESSION_KEY % data[:device_id]

      @redis.hset(key, "user_id", data[:user_id]) if data.has_key?(:user_id)
      @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
      @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)
      @redis.hset(key, "expire_at", data[:expire_at]) if data.has_key?(:expire_at)

      return TRUE
    else
      return FALSE
    end
  end

  def rd_pairing_session_delete(device_id = nil)
    return nil if nil == device_id
    key = PAIRING_SESSION_KEY % device_id
    hash_key = ["user_id", "status", "error_code", "expire_at"]

    hash_key.each do |item|
      @redis.hdel(key, item)
    end

    return TRUE
  end

#================ XMPP Methods =================
#===============================================

  def rd_xmpp_session_access(account=nil)
    return nil if nil == account

    key = XMPP_SESSION_KEY % account
    result = @redis.get(key)

    if !result.nil? then
      return result
    else
      return nil
    end
  end

  def rd_xmpp_session_insert(account=nil, device_id=nil)
    return nil if nil == account || nil == device_id

    key = XMPP_SESSION_KEY % account
    result = @redis.set(key, device_id)

    if "OK" == result then
      return device_id
    else
      return nil
    end
  end

  def rd_xmpp_session_update(account=nil, device_id=nil)
    return nil if nil == account || nil == device_id

    key = XMPP_SESSION_KEY % account
    result = @redis.set(key, device_id)

    if "OK" == result then
      return device_id
    else
      return nil
    end
  end

  def rd_xmpp_session_delete(account=nil)
    return nil if nil == account

    key = XMPP_SESSION_KEY % account
    result = @redis.del(key)

    if 1 == result then
      return TRUE
    else
      return FALSE
    end
  end

#=============== Device Methods ================
#===============================================
  def rd_device_session_access(device_id= nil)
    return nil if nil == device_id

    key = DEVICE_SESSION_KEY % device_id

    result = @redis.hgetall(key)
    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_device_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || (!data.has_key?(:ip) && !data.has_key?(:xmpp_account))

    key = DEVICE_SESSION_KEY % data[:device_id]

    @redis.hset(key, "ip", data[:ip]) if data.has_key?(:ip)
    @redis.hset(key, "xmpp_account", data[:xmpp_account]) if data.has_key?(:xmpp_account)

    return @redis.hgetall(key)
  end

  def rd_device_session_update(data={})
    return nil if data.empty? || !data.has_key?(:device_id) || (!data.has_key?(:ip) && !data.has_key?(:xmpp_account))

    isExist = self.rd_device_session_access(data[:device_id])
    if isExist then
      key = DEVICE_SESSION_KEY % data[:device_id]

      @redis.hset(key, "ip", data[:ip]) if data.has_key?(:ip)
      @redis.hset(key, "xmpp_account", data[:xmpp_account]) if data.has_key?(:xmpp_account)

      return TRUE
    else
      return FALSE
    end
  end

  def rd_device_session_delete(device_id = nil)
    return nil if nil == device_id

    key = DEVICE_SESSION_KEY % device_id
    hash_key = ["ip", "xmpp_account"]

    hash_key.each do |item|
      @redis.hdel(key, item)
    end

    return TRUE
  end

#================ Package Methods =================
#===============================================

  def rd_package_session_access(index = nil)
    return nil if nil == index

    key = PACKAGE_SESSION_KEY % index

    result = @redis.hgetall(key)

    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_package_session_update(data={})
     return nil if data.empty? || !data.has_key?(:index) || (!data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:status) && !data.has_key?(:error_code) && !data.has_key?(:package_list))

    isExist = self.rd_package_session_access(data[:index])
    if isExist then
      key = PACKAGE_SESSION_KEY % data[:index]
      @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)
      @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
      @redis.hset(key, "package_list", data[:package_list]) if data.has_key?(:package_list)

      return TRUE
    else
      return FALSE
    end
  end

#================ Upnp Methods =================
#===============================================

  def rd_upnp_session_access(index = nil)
    return nil if nil == index

    key = UPNP_SESSION_KEY % index

    result = @redis.hgetall(key)
    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_upnp_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:index) || (!data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:status) && !data.has_key?(:error_code) && !data.has_key?(:service_list) && !data.has_key?(:lan_ip))

    key = UPNP_SESSION_KEY % data[:index]

    @redis.hset(key, "user_id", data[:user_id]) if data.has_key?(:user_id)
    @redis.hset(key, "device_id", data[:device_id]) if data.has_key?(:device_id)
    @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
    @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)
    @redis.hset(key, "service_list", data[:service_list]) if data.has_key?(:service_list)
    @redis.hset(key, "lan_ip", data[:lan_ip]) if data.has_key?(:lan_ip)

    return @redis.hgetall(key)
  end

  def rd_upnp_session_update(data={})
    return nil if data.empty? || !data.has_key?(:index) || (!data.has_key?(:user_id) && !data.has_key?(:device_id) && !data.has_key?(:status) && !data.has_key?(:error_code) && !data.has_key?(:service_list) && !data.has_key?(:lan_ip))

    isExist = self.rd_upnp_session_access(data[:index])

    if isExist then
      key = UPNP_SESSION_KEY % data[:index]

      @redis.hset(key, "user_id", data[:user_id]) if data.has_key?(:user_id)
      @redis.hset(key, "device_id", data[:device_id]) if data.has_key?(:device_id)
      @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
      @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)
      @redis.hset(key, "service_list", data[:service_list]) if data.has_key?(:service_list)
      @redis.hset(key, "used_wan_port_list", data[:used_wan_port_list]) if data.has_key?(:used_wan_port_list)
      @redis.hset(key, "lan_ip", data[:lan_ip]) if data.has_key?(:lan_ip)

      return TRUE
    else
      return FALSE
    end
  end

  def rd_upnp_session_delete(index = nil)
    return nil if nil == index

    key = UPNP_SESSION_KEY % index
    hash_key = ["user_id", "device_id", "status", "error_code", "service_list", "lan_ip"]

    hash_key.each do |item|
      @redis.hdel(key, item)
    end

    return TRUE
  end

#================ DDNS Methods =================
#===============================================
  def rd_ddns_session_index_get
    key = DDNS_SESSION_INDEX_KEY
    return @redis.incr(key)
  end

  def rd_ddns_session_access(index = nil)
    return nil if nil == index

    key = DDNS_SESSION_KEY % index

    result = @redis.hgetall(key)
    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_ddns_session_insert(data={})
    return nil if data.empty? || !data.has_key?(:index) || (!data.has_key?(:device_id) && !data.has_key?(:host_name) && !data.has_key?(:domain_name) && !data.has_key?(:status) && !data.has_key?(:error_code))

    key = DDNS_SESSION_KEY % data[:index]

    @redis.hset(key, "device_id", data[:device_id]) if data.has_key?(:device_id)
    @redis.hset(key, "host_name", data[:host_name]) if data.has_key?(:host_name)
    @redis.hset(key, "domain_name", data[:domain_name]) if data.has_key?(:domain_name)
    @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
    @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)

    return @redis.hgetall(key)
  end

  def rd_ddns_session_update(data={})
    return nil if data.empty? || !data.has_key?(:index) || (!data.has_key?(:device_id) && !data.has_key?(:host_name) && !data.has_key?(:domain_name) && !data.has_key?(:status) && !data.has_key?(:error_code))

    isExist = self.rd_ddns_session_access(data[:index])

    if isExist then
      key = DDNS_SESSION_KEY % data[:index]

      @redis.hset(key, "device_id", data[:device_id]) if data.has_key?(:device_id)
      @redis.hset(key, "host_name", data[:host_name]) if data.has_key?(:host_name)
      @redis.hset(key, "domain_name", data[:domain_name]) if data.has_key?(:domain_name)
      @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
      @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)

      return TRUE
    else
      return FALSE
    end
  end

  def rd_ddns_session_delete(index=nil)
    return nil if nil == index

    key = DDNS_SESSION_KEY % index
    hash_key = ["device_id", "host_name", "domain_name", "status", "error_code"]

    hash_key.each do |item|
      @redis.hdel(key, item)
    end

    return TRUE
  end

#================ UNPAIR Methods ===============
#===============================================

  def rd_unpair_session_access(device_id=nil)
    return nil if nil == device_id

    key = UNPAIR_SESSION_KEY % device_id

    result = @redis.get(key)
    if !result.nil? then
      return result
    else
      return nil
    end
  end

  def rd_unpair_session_insert(device_id=nil)
    return nil if nil == device_id

    key = UNPAIR_SESSION_KEY % device_id

    result = @redis.set(key, "1")
    if "OK" == result then
      return device_id
    else
      return nil
    end
  end

  def rd_unpair_session_update(device_id=nil)
    return nil if nil == device_id

    key = UNPAIR_SESSION_KEY % device_id

    result = @redis.set(key, "1")
    if "OK" == result then
      return TRUE
    else
      return FALSE
    end
  end

  def rd_unpair_session_delete(device_id)
    return nil if nil == device_id

    key = UNPAIR_SESSION_KEY % device_id

    result = @redis.del(key)
    if 1 == result then
      return TRUE
    else
      return FALSE
    end
  end

#============== DDNS BATCH Methods =============
#===============================================
  def rd_ddns_batch_session_count
    key = DDNS_BATCH_SESSION_KEY
    result =@redis.zcount(key, '-inf', '+inf')

    if result then
      return result
    else
      return 0
    end
  end

  def rd_ddns_batch_session_access()
    key = DDNS_BATCH_SESSION_KEY
    result = @redis.zrange(key, 0, -1)

    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_ddns_batch_session_insert(value=nil, index=nil)
    return nil if nil == value || nil == index

    key = DDNS_BATCH_SESSION_KEY
    result = @redis.zadd(key, index.to_i, value)

    if result then
      return TRUE
    else
      return FALSE
    end
  end

  def rd_ddns_batch_session_delete(value)
    key = DDNS_BATCH_SESSION_KEY
    result = @redis.zrem(key, value)

    if result then
      return TRUE
    else
      return FALSE
    end
  end

#=========== DDNS BATCH LOCK Methods ===========
#===============================================
  def rd_ddns_batch_lock_set
    key = DDNS_BATCH_LOCK_KEY
    result = @redis.setex(key, DDNS_BATCH_LOCK_EXPIRE_TIME, "1")

    if "OK" == result then
      return TRUE
    else
      return FALSE
    end
  end

  def rd_ddns_batch_lock_isSet
    key = DDNS_BATCH_LOCK_KEY
    result = @redis.get(key)

    if !result.nil? then
      return TRUE
    else
      return FALSE
    end
  end

  def rd_ddns_batch_lock_delete
    key = DDNS_BATCH_LOCK_KEY
    result = @redis.del(key)

    if 1 == result then
      return TRUE
    else
      return FALSE
    end
  end

#========= DDNS RESEND SESSION Methods =========
#===============================================
  def rd_ddns_resend_session_access(index=nil)
    return nil if index.nil?

    key = DDNS_RESEND_SESSION_KEY % index
    result = @redis.get(key)

    if !result.nil? then
      return result
    else
      return nil
    end
  end

  def rd_ddns_resend_session_insert(index=nil)
    return nil if index.nil?

    key = DDNS_RESEND_SESSION_KEY % index
    result = @redis.setex(key, DDNS_RESEND_EXPIRE_TIME, "1")

    if "OK" == result then
      return TRUE
    else
      return FALSE
    end
  end

  def rd_ddns_resend_session_delete(index=nil)
    return nil if index.nil?

    key = DDNS_RESEND_SESSION_KEY % index
    result = @redis.del(key)

    if 1 == result then
      return TRUE
    else
      return FALSE
    end
  end

  #================ LED INDICATOR Methods ===============
  #===============================================

  def led_indicator_session_access(index=nil)
    return nil if index.nil?
    key = LED_INDICATOR_SESSION_KEY % index
    result = @redis.hgetall(key)
    if !result.nil? then
      return result
    else
      return nil
    end
  end

  def close
    @redis.quit
  end

#========== PERMISSION SESSION Methods =========
#===============================================

  def rd_permission_session_access(index=nil)
    return nil if index.nil?

    key = USER_PERMISSION_KEY % [index]
    result = @redis.hgetall(key)
    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_permission_session_update(data={})
    return nil if data.empty? || !data.has_key?(:index) || !data.has_key?(:status)

    isExist = self.rd_permission_session_access(data[:index])
    if isExist then
      key = USER_PERMISSION_KEY % [data[:index]]

      @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
      @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)

      return TRUE
    else
      return FALSE
    end
  end

#========== DEVICE INFO SESSION Methods =========
#===============================================

  def rd_device_info_session_access(index = nil)
    return nil if nil == index

    key = DEVICE_INFORMATION_KEY % [index]
    result = @redis.hgetall(key)
    if !result.empty? then
      return result
    else
      return nil
    end
  end

  def rd_device_info_session_update(data={})
    return nil if data.empty? || !data.has_key?(:session_id)  || !data.has_key?(:status)

    isExist = self.rd_device_info_session_access(data[:session_id])
    if isExist then
      key = DEVICE_INFORMATION_KEY % [data[:session_id]]

      @redis.hset(key, "user_id", data[:user_id]) if data.has_key?(:user_id)
      @redis.hset(key, "status", data[:status]) if data.has_key?(:status)
      @redis.hset(key, "error_code", data[:error_code]) if data.has_key?(:error_code)
      @redis.hset(key, "info", data[:device_info]) if data.has_key?(:device_info)

      return TRUE
    else
      return FALSE
    end
  end
end