require_relative '../lib/bot_redis_access'
require 'yaml'
#require 'pry'

class BotRedisAccess

  

end
describe BotRedisAccess do
  let(:rd){BotRedisAccess.new}
  
  before(:each) do
    until (value = rd.rd_ddns_batch_session_access) == nil
      rd.rd_ddns_batch_session_delete(value)
    end
  end

  it 'Config file check' do
    config_file = File.join(File.dirname(__FILE__), REDIS_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    expect(config).to be_an_instance_of(Hash)
    
    expect(config).to have_key('rd_host')
    expect(config).to have_key('rd_port')
    expect(config).to have_key('rd_db')
    
    expect(config['rd_host']).not_to eq('xxx')
    expect(config['rd_port']).not_to eq('xxx')
    expect(config['rd_db']).not_to eq('xxx')
  end
  
  it 'Initialize Redis class' do
      expect(rd).to be_an_instance_of(BotRedisAccess)
  end
  
  context "Verify Pairing session table" do
    it 'Confirm pairing session access methods' do
      methods = ['rd_pairing_session_access',
                 'rd_pairing_session_insert',
                 'rd_pairing_session_update',
                 'rd_pairing_session_delete',]
    
      methods.each do |method|
         expect(rd).to respond_to(method.to_sym)
      end
    end
    
    it 'Access non-exist record from Pairing session table' do
      device_id = Time.now.to_i
      result = rd.rd_pairing_session_access(device_id)
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from Pairing session table' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: "start", error_code: 789, expire_at: "2014-01-14 13:23:34"}
      rd.rd_pairing_session_insert(data)
      result = rd.rd_pairing_session_access(device_id)
      rd.rd_pairing_session_delete(device_id)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("user_id")
      expect(result).to have_key("status")
      expect(result).to have_key("error_code")
      expect(result).to have_key("expire_at")
      
      expect(result['user_id']).to eq("2")
      expect(result['status']).to eq("start")
      expect(result['error_code'].to_i).to eq(789)
      expect(result['expire_at']).to eq("2014-01-14 13:23:34")
    end
    
    it 'Update pairing session record' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: "start", error_code: 789, expire_at: "2014-01-14 13:23:34"}
      rd.rd_pairing_session_insert(data)
      result_insert = rd.rd_pairing_session_access(device_id)
      
      data = {device_id: device_id, user_id: 2, status: "wait", error_code: 999, expire_at: "2014-01-15 13:23:34"}
      rd.rd_pairing_session_update(data)
      result_updated = rd.rd_pairing_session_access(device_id)
      
      rd.rd_pairing_session_delete(device_id)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("user_id")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      expect(result_insert).to have_key("expire_at")
      
      expect(result_insert['user_id']).to eq("2")
      expect(result_insert['status']).to eq("start")
      expect(result_insert['error_code'].to_i).to eq(789)
      expect(result_insert['expire_at']).to eq("2014-01-14 13:23:34")
      
      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("user_id")
      expect(result_updated).to have_key("status")
      expect(result_updated).to have_key("error_code")
      expect(result_updated).to have_key("expire_at")
      
      expect(result_updated['user_id']).to eq("2")
      expect(result_updated['status']).to eq("wait")
      expect(result_updated['error_code'].to_i).to eq(999)
      expect(result_updated['expire_at']).to eq("2014-01-15 13:23:34")
    end
    
    it 'Update nonexistent pairing session record' do
      device_id = Time.now.to_i
      
      data = {device_id: device_id, user_id: 2, status: "wait", error_code: 999, expire_at: "2014-01-15 13:23:34"}
      result = rd.rd_pairing_session_update(data)
      
      expect(result).to be false
    end
    
    it 'Delete pairing session record' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: "start", error_code: 999, expire_at: "2014-01-14 13:23:34"}
      rd.rd_pairing_session_insert(data)
      result_insert = rd.rd_pairing_session_access(device_id)
      rd.rd_pairing_session_delete(device_id)
      result_deleted = rd.rd_pairing_session_access(device_id)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("user_id")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      expect(result_insert).to have_key("expire_at")
      
      expect(result_deleted).to be_nil
    end
  end
  
  context "Verify Devices session table" do
    it 'Access non-exist record from Device session table' do
      device_id = Time.now.to_i
      result = rd.rd_device_session_access(device_id)
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from Device session table' do
      device_id = Time.now.to_i
      data = {device_id: device_id, ip: "10.1.1.103", xmpp_account: "bot2"}
      rd.rd_device_session_insert(data)
      result = rd.rd_device_session_access(device_id)
      rd.rd_device_session_delete(device_id)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("ip")
      expect(result).to have_key("xmpp_account")
      
      expect(result['ip']).to eq("10.1.1.103")
      expect(result['xmpp_account']).to eq("bot2")
    end
    
    it 'Update device session record' do
      device_id = Time.now.to_i
      data = {device_id: device_id, ip: "10.1.1.103", xmpp_account: "bot2"}
      rd.rd_device_session_insert(data)
      result_insert = rd.rd_device_session_access(device_id)
      
      data = {device_id: device_id, ip: "10.1.1.104", xmpp_account: "bot3"}
      rd.rd_device_session_update(data)
      result_updated = rd.rd_device_session_access(device_id)
      
      rd.rd_device_session_delete(device_id)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("ip")
      expect(result_insert).to have_key("xmpp_account")
      
      expect(result_insert['ip']).to eq("10.1.1.103")
      expect(result_insert['xmpp_account']).to eq("bot2")
      
      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("ip")
      expect(result_updated).to have_key("xmpp_account")
      
      expect(result_updated['ip']).to eq("10.1.1.104")
      expect(result_updated['xmpp_account']).to eq("bot3")
    end
    
    it 'Update nonexistent device session record' do
      device_id = Time.now.to_i
      
      data = {device_id: device_id, ip: "10.1.1.104", xmpp_account: "bot3"}
      result = rd.rd_device_session_update(data)
      
      expect(result).to be false
    end
    
    it 'Delete device session record' do
      device_id = Time.now.to_i
      data = {device_id: device_id, ip: "10.1.1.103", xmpp_account: "bot2"}
      rd.rd_device_session_insert(data)
      result_insert = rd.rd_device_session_access(device_id)
      rd.rd_device_session_delete(device_id)
      result_deleted = rd.rd_device_session_access(device_id)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("ip")
      expect(result_insert).to have_key("xmpp_account")
      
      expect(result_deleted).to be_nil
    end
  end
  
  context "Verify UPNP session table" do
    it 'Access non-exist record from UPNP session table' do
      index = Time.now.to_i
      result = rd.rd_upnp_session_access(index)
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from UPNP session table' do
      index = Time.now.to_i
      data = {index: index, user_id: 2, device_id: 1, status: "start", error_code: 789, service_list: "[]", lan_ip: "10.1.1.110"}
      rd.rd_upnp_session_insert(data)
      result = rd.rd_upnp_session_access(index)
      rd.rd_upnp_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("user_id")
      expect(result).to have_key("device_id")
      expect(result).to have_key("status")
      expect(result).to have_key("error_code")
      expect(result).to have_key("service_list")
      expect(result).to have_key("lan_ip")
      
      expect(result['user_id']).to eq("2")
      expect(result['device_id']).to eq("1")
      expect(result['status']).to eq("start")
      expect(result['error_code'].to_i).to eq(789)
      expect(result['service_list']).to eq("[]")
      expect(result['lan_ip']).to eq("10.1.1.110")
    end
    
    it 'Update UPNP session record' do
      index = Time.now.to_i
      data = {index: index, user_id: 2, device_id: 1, status: "start", error_code: 789, service_list: "[]", lan_ip: "10.1.1.110"}
      rd.rd_upnp_session_insert(data)
      result_insert = rd.rd_upnp_session_access(index)
      
      data = {index: index, user_id: 3, device_id: 4, status: "wait", error_code: 999, service_list: "[{}]", lan_ip: "10.1.1.113"}
      rd.rd_upnp_session_update(data)
      result_updated = rd.rd_upnp_session_access(index)
      
      rd.rd_upnp_session_delete(index)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("user_id")
      expect(result_insert).to have_key("device_id")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      expect(result_insert).to have_key("service_list")
      expect(result_insert).to have_key("lan_ip")
      
      expect(result_insert['user_id']).to eq("2")
      expect(result_insert['device_id']).to eq("1")
      expect(result_insert['status']).to eq("start")
      expect(result_insert['error_code'].to_i).to eq(789)
      expect(result_insert['service_list']).to eq("[]")
      expect(result_insert['lan_ip']).to eq("10.1.1.110")
      
      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("user_id")
      expect(result_updated).to have_key("device_id")
      expect(result_updated).to have_key("status")
      expect(result_updated).to have_key("error_code")
      expect(result_updated).to have_key("service_list")
      expect(result_updated).to have_key("lan_ip")
      
      expect(result_updated['user_id']).to eq("3")
      expect(result_updated['device_id']).to eq("4")
      expect(result_updated['status']).to eq("wait")
      expect(result_updated['error_code'].to_i).to eq(999)
      expect(result_updated['service_list']).to eq("[{}]")
      expect(result_updated['lan_ip']).to eq("10.1.1.113")
    end
    
    it 'Update nonexistent UPNP session record' do
      index = Time.now.to_i
      
      data = {index: index, user_id: 3, device_id: 4, status: "wait", error_code: 789, service_list: "[{}]", lan_ip: "10.1.1.113"}
      result = rd.rd_upnp_session_update(data)
      
      expect(result).to be false
    end
    
    it 'Delete UPNP session record' do
      index = Time.now.to_i
      data = {index: index, user_id: 2, device_id: 1, status: "start", error_code: 789, service_list: "[]", lan_ip: "10.1.1.113"}
      rd.rd_upnp_session_insert(data)
      result_insert = rd.rd_upnp_session_access(index)
      rd.rd_upnp_session_delete(index)
      result_deleted = rd.rd_upnp_session_access(index)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("user_id")
      expect(result_insert).to have_key("device_id")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      expect(result_insert).to have_key("service_list")
      expect(result_insert).to have_key("lan_ip")
      
      expect(result_deleted).to be_nil
    end
  end
#start of package session
  context "Verify Package session table" do
    it 'Access non-exist record from Package session table' do
      index = Time.now.to_i
      result = rd.rd_package_session_access(index)
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from package session table' do
      index = Time.now.to_i
      data = {index: index, user_id: 2, device_id: 1, status: "start", package_list: "[]"}
      rd.rd_package_session_insert(data)
      result = rd.rd_package_session_access(index)
      rd.rd_package_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("user_id")
      expect(result).to have_key("device_id")
      expect(result).to have_key("status")
      expect(result).to have_key("package_list")
      
      expect(result['user_id']).to eq("2")
      expect(result['device_id']).to eq("1")
      expect(result['status']).to eq("start")
      expect(result['package_list']).to eq("[]")
    end
    
    it 'Update Package session record' do
      index = Time.now.to_i
      data = {index: index, user_id: 2, device_id: 1, status: "start", error_code: 789, package_list: "[]"}
      rd.rd_package_session_insert(data)
      result_insert = rd.rd_package_session_access(index)
      
      data = {index: index, user_id: 3, device_id: 4, status: "wait", error_code: 999, package_list: "[{}]"}
      rd.rd_package_session_update(data)
      result_updated = rd.rd_package_session_access(index)
      
      rd.rd_package_session_delete(index)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("user_id")
      expect(result_insert).to have_key("device_id")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      expect(result_insert).to have_key("package_list")
      
      expect(result_insert['user_id']).to eq("2")
      expect(result_insert['device_id']).to eq("1")
      expect(result_insert['status']).to eq("start")
      expect(result_insert['error_code'].to_i).to eq(789)
      expect(result_insert['package_list']).to eq("[]")
      
      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("user_id")
      expect(result_updated).to have_key("device_id")
      expect(result_updated).to have_key("status")
      expect(result_updated).to have_key("error_code")
      expect(result_updated).to have_key("package_list")
      
      expect(result_updated['user_id']).to eq("2")
      expect(result_updated['device_id']).to eq("1")
      expect(result_updated['status']).to eq("wait")
      expect(result_updated['error_code'].to_i).to eq(999)
      expect(result_updated['package_list']).to eq("[{}]")
    end
    
    it 'Update nonexistent Package session record' do
      index = Time.now.to_i
      
      data = {index: index+1, user_id: 3, device_id: 4, status: "wait", error_code: 789, package_list: "[{}]", }
      result = rd.rd_package_session_update(data)
      
      expect(result).to be false
    end
  end
#end of package redis 
#begin of device info redis
  context "Verify Device Information  table" do
    it 'Access non-exist record from Device Information session table' do
      index = Time.now.to_i
      result = rd.rd_device_info_session_access(index)
      expect(result).to be_nil
    end

    it 'Access exist record from Device Information session table' do
      index = Time.now.to_i
      data = {session_id: index, status: "start", info: "[]"}
      rd.rd_device_info_session_insert(data)
      result = rd.rd_device_info_session_access(index)
      rd.rd_device_info_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("status")
      expect(result).to have_key("info")
      
      expect(result['status']).to eq("start")
      expect(result['info']).to eq("[]")
    end
    
    it 'Update device Information session record' do
      index = Time.now.to_i
      data = {session_id: index, status: "start", info: "[]"}
      rd.rd_device_info_session_insert(data)
      result = rd.rd_device_info_session_access(index)
      
      data = {session_id: index, status: "wait", info: "[]", error_code: 999}
      rd.rd_device_info_session_update(data)
      result_updated = rd.rd_device_info_session_access(index)
      
      rd.rd_device_info_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      expect(result).to have_key("status")
      expect(result).to have_key("info")
      
      expect(result['status']).to eq("start")
      expect(result['info']).to eq("[]")
      
      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("status")
      expect(result_updated).to have_key("info")
      
      expect(result_updated['status']).to eq("wait")
      expect(result_updated['info']).to eq("[]")
      expect(result_updated['error_code']).to eq("999")
    end

    it 'Update nonexistent Device Information session record' do
      index = Time.now.to_i+2
      
      data = {session_id: index, status: "wait", info: "[]", error_code: 999}
      result = rd.rd_device_info_session_update(data)
      
      expect(result).to be false
    end
  end
#end of device info redis


#begin of permission redis
  context "Verify PERMISSION  table" do
    it 'Access non-exist record from PERMISSION session table' do
      index = Time.now.to_i
      result = rd.rd_permission_session_access(index)
      expect(result).to be_nil
    end

    it 'Access exist record from PERMISSION session table' do
      index = Time.now.to_i
      data = {index: index, status: "start"}
      rd.rd_permission_session_insert(data)
      result = rd.rd_permission_session_access(index)
      rd.rd_permission_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("status")
      
      expect(result['status']).to eq("start")
    end
    
    it 'Update PERMISSION session record' do
      index = Time.now.to_i
      data = {index: index, status: "start"}
      rd.rd_permission_session_insert(data)
      result = rd.rd_permission_session_access(index)
      
      data = {index: index, status: "wait", error_code: 999}
      rd.rd_permission_session_update(data)
      result_updated = rd.rd_permission_session_access(index)
      
      rd.rd_permission_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      expect(result).to have_key("status")
      
      expect(result['status']).to eq("start")
      
      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("status")
      
      expect(result_updated['status']).to eq("wait")
      expect(result_updated['error_code']).to eq("999")
    end

    it 'Update nonexistent PERMISSION session record' do
      index = Time.now.to_i+2
      
      data = {index: index, status: "wait", info: "[]", error_code: 999}
      result = rd.rd_permission_session_update(data)
      
      expect(result).to be false
    end
  end
#end of permission redis

#begin of led indicator redis
  context "Verify LED Indicator  table" do
    it 'Access non-exist record from LED Indicator session table' do
      index = Time.now.to_i
      result = rd.led_indicator_session_access(index)
      expect(result).to eq({})
    end

    it 'Access exist record from LED Indicator session table' do
      index = Time.now.to_i
      data = {session_id: index, device_id: 1}
      rd.rd_led_indicator_session_insert(data)
      result = rd.led_indicator_session_access(index)
      rd.rd_led_indicator_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      expect(result).to have_key("device_id")
      
      expect(result['device_id']).to eq("1")
    end
    
    
  end
#end of led indicator redis

  context "Verify DDNS session table" do
    it 'Get DDNS session index' do
      previous = rd.rd_ddns_session_index_get
      result = rd.rd_ddns_session_index_get

      expect(result.to_i).to eq(previous.to_i + 1)
    end

    it 'Access non-exist record from DDNS session table' do
      index = Time.now.to_i
      result = rd.rd_ddns_session_access(index)
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from DDNS session table' do
      index = Time.now.to_i
      data = {index: index, device_id: 1, host_name: "myhostname", domain_name: "ecoworkinc.com", status: "start", error_code: 987}
      rd.rd_ddns_session_insert(data)
      result = rd.rd_ddns_session_access(index)
      rd.rd_ddns_session_delete(index)
      
      expect(result).to be_an_instance_of(Hash)
      
      expect(result).to have_key("device_id")
      expect(result).to have_key("host_name")
      expect(result).to have_key("domain_name")
      expect(result).to have_key("status")
      expect(result).to have_key("error_code")
      
      expect(result['device_id']).to eq("1")
      expect(result['host_name']).to eq("myhostname")
      expect(result['domain_name']).to eq("ecoworkinc.com")
      expect(result['status']).to eq("start")
      expect(result['error_code'].to_i).to eq(987)
    end
    
    it 'Update DDNS session record' do
      index = Time.now.to_i
      data = {index: index, device_id: 1, host_name: "myhostname", domain_name: "ecoworkinc.com", status: "start", error_code: 987}
      rd.rd_ddns_session_insert(data)
      result_insert = rd.rd_ddns_session_access(index)
      
      data = {index: index, device_id: 1, host_name: "myhostname", domain_name: "ecoworkinc.com", status: "wait", error_code: 743}
      rd.rd_ddns_session_update(data)
      result_updated = rd.rd_ddns_session_access(index)
      
      rd.rd_ddns_session_delete(index)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("device_id")
      expect(result_insert).to have_key("host_name")
      expect(result_insert).to have_key("domain_name")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      
      expect(result_insert['device_id']).to eq("1")
      expect(result_insert['host_name']).to eq("myhostname")
      expect(result_insert['domain_name']).to eq("ecoworkinc.com")
      expect(result_insert['status']).to eq("start")
      expect(result_insert['error_code'].to_i).to eq(987)

      expect(result_updated).to be_an_instance_of(Hash)
      expect(result_updated).to have_key("device_id")
      expect(result_updated).to have_key("host_name")
      expect(result_updated).to have_key("domain_name")
      expect(result_updated).to have_key("status")
      expect(result_updated).to have_key("error_code")
      
      expect(result_updated['device_id']).to eq("1")
      expect(result_updated['host_name']).to eq("myhostname")
      expect(result_updated['domain_name']).to eq("ecoworkinc.com")
      expect(result_updated['status']).to eq("wait")
      expect(result_updated['error_code'].to_i).to eq(743)
    end
    
    it 'Update nonexistent DDNS session record' do
      index = Time.now.to_i
      
      data = {index: index, device_id: 1, host_name: "myhostname", domain_name: "ecoworkinc.com", status: "wait", error_code: 743}
      result = rd.rd_ddns_session_update(data)
      
      expect(result).to be false
    end
    
    it 'Delete DDNS session record' do
      index = Time.now.to_i
      data = {index: index, device_id: 1, host_name: "myhostname", domain_name: "ecoworkinc.com", status: "start", error_code: 199}
      rd.rd_ddns_session_insert(data)
      result_insert = rd.rd_ddns_session_access(index)
      rd.rd_ddns_session_delete(index)
      result_deleted = rd.rd_ddns_session_access(index)
      
      expect(result_insert).to be_an_instance_of(Hash)
      expect(result_insert).to have_key("device_id")
      expect(result_insert).to have_key("host_name")
      expect(result_insert).to have_key("domain_name")
      expect(result_insert).to have_key("status")
      expect(result_insert).to have_key("error_code")
      
      expect(result_deleted).to be_nil
    end
  end
  
  context "Verify Unpair session table" do
    it 'Access non-exist record from Unpair session table' do
      index = Time.now.to_i
      result = rd.rd_unpair_session_access(index)
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from Unpair session table' do
      index = Time.now.to_i
      
      rd.rd_unpair_session_insert(index)
      result = rd.rd_unpair_session_access(index)
      rd.rd_unpair_session_delete(index)
      
      expect(result).to eq("1")
    end
    
    it 'Update Unpair session record' do
      index = Time.now.to_i
      
      rd.rd_unpair_session_insert(index)
      result_insert = rd.rd_unpair_session_access(index)
      
      rd.rd_unpair_session_update(index)
      result_updated = rd.rd_unpair_session_access(index)
      
      rd.rd_unpair_session_delete(index)
      
      expect(result_insert).to eq("1")
      expect(result_updated).to eq("1")
    end
    
    it 'Delete Unpair session record' do
      index = Time.now.to_i
      
      rd.rd_unpair_session_insert(index)
      result_insert = rd.rd_unpair_session_access(index)
      rd.rd_unpair_session_delete(index)
      result_deleted = rd.rd_unpair_session_access(index)
      
      expect(result_insert).to eq("1")
      expect(result_deleted).to be_nil
    end 
  end
  
  context "Verify XMPP session table" do
    it 'Access non-exist record from XMPP session table' do
      account = 'bot%d' % Time.now.to_i
      result = rd.rd_xmpp_session_access(account)

      expect(result).to be_nil
    end

    it 'Access exist record from XMPP session table' do
      device_id = Time.now.to_i
      account = 'bot%d' % device_id

      rd.rd_xmpp_session_insert(account, device_id)
      result = rd.rd_xmpp_session_access(account)
      rd.rd_xmpp_session_delete(account)

      expect(result).to eq(device_id.to_s)
    end

    it 'Update XMPP session record' do
      device_id = Time.now.to_i
      account = 'bot%d' % device_id
      new_device_id = device_id + 1

      rd.rd_xmpp_session_insert(account, device_id)
      result_insert = rd.rd_xmpp_session_access(account)

      rd.rd_xmpp_session_update(account, new_device_id)
      result_updated = rd.rd_xmpp_session_access(account)

      rd.rd_xmpp_session_delete(account)

      expect(result_insert).to eq(device_id.to_s)
      expect(result_updated).to eq(new_device_id.to_s)
    end

    it 'Delete Unpair session record' do
      device_id = Time.now.to_i
      account = 'bot%d' % device_id

      rd.rd_xmpp_session_insert(account, device_id)
      result_insert = rd.rd_xmpp_session_access(account)
      rd.rd_xmpp_session_delete(account)
      result_deleted = rd.rd_xmpp_session_access(account)

      expect(result_insert).to eq(device_id.to_s)
      expect(result_deleted).to be_nil
    end
  end

  context "Verify DDNS BATCH session table" do
    it 'Get DDNS BATCH session count number' do
      result = rd.rd_ddns_batch_session_count

      expect(result).not_to be_nil
    end

    it 'Access non-exist record from DDNS BATCH session table' do
      result = rd.rd_ddns_batch_session_access()
      
      expect(result).to be_nil
    end
    
    it 'Access exist record from DDNS BATCH session table' do
      index = Time.now.to_i
      value = '{"name":"hibari", "age":%d}' % index
      
      rd.rd_ddns_batch_session_insert(value, index)
      result = rd.rd_ddns_batch_session_access()
      rd.rd_ddns_batch_session_delete(value)
      
      expect(result).to be_an_instance_of(Array)
    end
    
    it 'Delete DDNS BATCH session record' do
      index = Time.now.to_i
      value = '{"name":"hibari", "age":%d}' % index
      
      rd.rd_ddns_batch_session_insert(value, index)
      result_insert = rd.rd_ddns_batch_session_access()
      rd.rd_ddns_batch_session_delete(value)
      result_delete = rd.rd_ddns_batch_session_access()
      
      expect(result_insert).to be_an_instance_of(Array)
      expect(result_delete).to be_nil
    end 
  end
  
  context "Verify DDNS BATCH LOCK table" do
    it 'Access non-exist record from DDNS BATCH LOCK table' do
      result = rd.rd_ddns_batch_lock_isSet
      expect(result).to be false
    end
    
    it 'Access exist record from DDNS BATCH LOCK table' do
      rd.rd_ddns_batch_lock_set
      result = rd.rd_ddns_batch_lock_isSet
      rd.rd_ddns_batch_lock_delete
      
      expect(result).to be true
    end
    
    it 'Delete DDNS RETRY LOCK record' do
      rd.rd_ddns_batch_lock_set
      result_set = rd.rd_ddns_batch_lock_isSet
      rd.rd_ddns_batch_lock_delete
      result_delete = rd.rd_ddns_batch_lock_isSet
      
      expect(result_set).to be true
      expect(result_delete).to be false
    end
  end
  
  context "Verify DDNS RESEND SESSION table" do
    it 'Access non-exist record from DDNS RESEND SESSION table' do
      index = Time.now.to_i
      
      result = rd.rd_ddns_resend_session_access(index)
      expect(result).to be_nil
    end
    
    it 'Access exist record from DDNS RESEND SESSION table' do
      index = Time.now.to_i
      
      resend_insert = rd.rd_ddns_resend_session_insert(index)
      resend_access = rd.rd_ddns_resend_session_access(index)
      isDeleted = rd.rd_ddns_resend_session_delete(index)
      
      expect(resend_insert).to be true
      expect(resend_access.to_i).to eq(1)
      expect(isDeleted).to be true
    end
    
    it 'Delete DDNS RESEND SESSION record' do
      index = Time.now.to_i
      
      resend_insert = rd.rd_ddns_resend_session_insert(index)
      resend_access = rd.rd_ddns_resend_session_access(index)
      isDeleted = rd.rd_ddns_resend_session_delete(index)
      
      expect(resend_insert).to be true
      expect(resend_access.to_i).to eq(1)
      expect(isDeleted).to be true
    end
  end
  
  it 'Close Redis connection' do
    rd.close
  end
  
end
