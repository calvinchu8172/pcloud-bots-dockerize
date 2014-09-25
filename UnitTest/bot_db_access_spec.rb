require_relative '../lib/bot_db_access'
require 'yaml'

#DB_CONFIG_FILE = '../config/bot_db_config.yml'

describe BotDBAccess do
  let(:db) {BotDBAccess.new}
  
  it 'Config file check' do
    config_file = File.join(File.dirname(__FILE__), DB_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    expect(config).to be_an_instance_of(Hash)
    
    expect(config).to have_key('db_host')
    expect(config).to have_key('db_socket')
    expect(config).to have_key('db_name')
    expect(config).to have_key('db_userid')
    expect(config).to have_key('db_userpw')
    expect(config).to have_key('db_pool')
    
    expect(config['db_host']).not_to eq('xxx')
    expect(config['db_socket']).not_to eq('xxx')
    expect(config['db_name']).not_to eq('xxx')
    expect(config['db_userid']).not_to eq('xxx')
    expect(config['db_userpw']).not_to eq('xxx')
    expect(config['db_pool']).not_to eq('xxx')
  end
  
  it 'Initialize DB class' do
      expect(db).to be_an_instance_of(BotDBAccess)
  end
  
  context "About User table" do
    it 'Access user table' do
      user = db.db_user_access(1)
      expect(user).to respond_to(:id)
    
      user = db.db_user_access(0)
      expect(user).to be_nil
    end
  end
  
  context "About Pair & Pair Session table" do
    pair_methods = ['db_pairing_access',
                    'db_pairing_insert',
                    'db_pairing_update',
                    'db_pairing_delete']

    pair_id = nil
    pair_data = {user_id: 'test@ecoworkinc.com', device_id: 123456789}
    
    it 'Existence of Pair & Pair Session methods check' do
      pair_methods.each do |x|
        expect(db).to respond_to(x.to_sym)
      end
    end
    
    it 'Access non-exist record from Pairing table' do
      pair = db.db_pairing_access(pair_data)
      expect(pair).to be_nil
    end
    
    it 'Add new record into Pairing table' do
      pair = db.db_pairing_insert(pair_data[:user_id], pair_data[:device_id])
      expect(pair).to respond_to(:id)
      pair_id = pair.id
      
      access = db.db_pairing_access({id: pair_id})
      expect(access).to respond_to(:id)
    end
    
    it 'Update Pairing record' do
      device_id = 12345678
      pair_data[:id] = pair_id
      pair_data[:device_id] = device_id
      pair_data[:enabled] = 0
      isSuccess = db.db_pairing_update(pair_data)
      expect(isSuccess).to be true
      
      pair = db.db_pairing_access({id: pair_id})
      expect(pair).to respond_to(:id)
      expect(pair.device_id.to_d).to eq(device_id)
      
      pair_data[:id] = 0
      isSuccess = db.db_pairing_update(pair_data)
      expect(isSuccess).to be false
    end
    
    it 'Delete Pairing record' do
      isSuccess = db.db_pairing_delete(pair_id)
      expect(isSuccess).to be true
      pair_id = nil
      
      isSuccess = db.db_pairing_delete(0)
      expect(isSuccess).to be false
    end
  end
  
  context "About Device & DeviceSession table" do
    device_methods = ['db_device_access',
                      'db_device_insert',
                      'db_device_update',
                      'db_device_delete',
                      'db_device_session_access',
                      'db_device_session_insert',
                      'db_device_session_update',
                      'db_device_session_delete']
    
    device_id = nil
    device_session_id = nil
    
    it 'Existence of Device & Device Session methods check' do
      device_methods.each do |x|
        expect(db).to respond_to(x.to_sym)
      end
    end
    
    it 'Access non-exist record from Device table' do
      data = {serial_number: 'NS123456789', mac_address: '0e:11:83:t6', model_name: 'beta2', firmware_version: '1.000.000'}
      device = db.db_device_access(data)
      expect(device).to be_nil
    end
    
    it 'Add new record into Device table re-test access method' do
      data = {serial_number: 'NS123456789', mac_address: '0e:11:83:t6', model_name: 'beta2', firmware_version: '1.000.000'}
      device = db.db_device_insert(data)
      expect(device).to respond_to(:id)
      device_id = device.id
      
      access = db.db_device_access({id: device_id})
      expect(access).to respond_to(:id)
    end
    
    it 'Update Device record' do
      data = {id: device_id, serial_number: 'NS123456789', mac_address: '0e:11:83:t6', model_name: 'beta2', firmware_version: '1.000.001'}
      isSuccess = db.db_device_update(data)
      expect(isSuccess).to be true
      
      data = {id: 0, serial_number: 'NS123456789', mac_address: '0e:11:83:t6', model_name: 'beta2', firmware_version: '1.000.001'}
      isSuccess = db.db_device_update(data)
      expect(isSuccess).to be false
    end
    
    it 'Delete Device record' do
      isSuccess = db.db_device_delete(device_id)
      expect(isSuccess).to be true
      device_id = nil
      
      isSuccess = db.db_device_delete(0)
      expect(isSuccess).to be false
    end
    
    it 'Access non-exist record of Device Session table' do
      data = {device_id: 1234567, ip: '10.1.1.113', xmpp_account: 'bot3', password: '12345'}
      session = db.db_device_session_access(data)
      expect(session).to be_nil
    end
    
    it 'Add new record into Device Session table and re-test access method' do
      data = {device_id: 1234567, ip: '10.1.1.113', xmpp_account: 'bot3', password: '12345'}
      session = db.db_device_session_insert(data)
      expect(session).to respond_to(:id)
      expect(session.xmpp_account).to eq('bot3')
      device_session_id = session.id
      
      access = db.db_device_session_access({id: device_session_id})
      expect(access).to respond_to(:id)
    end
    
    it 'Update Device Session record' do
      data = {id: device_session_id, device_id: 1234567, ip: '10.1.1.113', xmpp_account: 'bot4', password: '12345'}
      isSuccess = db.db_device_session_update(data)
      expect(isSuccess).to be true
      
      session = db.db_device_session_access({id: device_session_id})
      expect(session.xmpp_account).to eq('bot4')
    end
    
    it 'Delete Device session record' do
      isSuccess = db.db_device_session_delete(device_session_id)
      expect(isSuccess).to be true
      device_session_id = nil
      
      isSuccess = db.db_device_session_delete(0)
      expect(isSuccess).to be false
    end
  end
  
  context "About DDNS & DDNS Session table" do
    ddns_methods = ['db_ddns_access',
                    'db_ddns_insert',
                    'db_ddns_update',
                    'db_ddns_delete',
                    'db_ddns_session_access',
                    'db_ddns_session_insert',
                    'db_ddns_session_update',
                    'db_ddns_session_delete',]
    
    ddns_id = nil
    ddns_session_id = nil
    
    it 'Existence of DDNS & DDNS Session methods check' do
      ddns_methods.each do |x|
        expect(db).to respond_to(x.to_sym)
      end
    end
    
    it 'Access non-exist record from DDNS table' do
      data = {device_id: 123456789, ip_address: '10.1.1.111', full_domain: 'mytest3.demo.ecoworkinc.com.'}
      ddns = db.db_ddns_access(data)
      expect(ddns).to be_nil
    end
    
    it 'Add new record into DDNS table and re-test access method' do
      data = {device_id: 123456789, ip_address: '10.1.1.111', full_domain: 'mytest3.demo.ecoworkinc.com.'}
      ddns = db.db_ddns_insert(data)
      expect(ddns).to respond_to(:id)
      ddns_id = ddns.id
      
      access = db.db_ddns_access({id: ddns_id})
      expect(access).to respond_to(:id)
    end
    
    it 'Update DDNS record' do
      ip_address = '10.1.1.112'
      data = {id: ddns_id, device_id: 123456789, ip_address: ip_address, full_domain: 'mytest3.demo.ecoworkinc.com.'}
      isSuccess = db.db_ddns_update(data)
      expect(isSuccess).to be true
      
      ddns = db.db_ddns_access({id: ddns_id})
      expect(ddns.ip_address).to eq(ip_address)
    end
    
    it 'Delete DDNS record' do
      isSuccess = db.db_ddns_delete(ddns_id)
      expect(isSuccess).to be true
      ddns_id = nil
      
      isSuccess = db.db_ddns_delete(0)
      expect(isSuccess).to be false
    end
    
    it 'Access non-exist record from DDNS Session table' do
      data = {device_id: 12345678, full_domain: 'mytest3.demo.ecoworkinc.com.', status: 0}
      session = db.db_ddns_session_access(data)
      expect(session).to be_nil
    end
    
    it 'Add new record into DDNS Session table and re-test access method' do
      data = {device_id: 12345678, full_domain: 'mytest3.demo.ecoworkinc.com.', status: 0}
      session = db.db_ddns_session_insert(data)
      expect(session).to respond_to(:id)
      ddns_session_id = session.id
      
      access = db.db_ddns_session_access({id: ddns_session_id})
      expect(access).to respond_to(:id)
    end
    
    it 'Update DDNS Session record' do
      data = {id: ddns_session_id, device_id: 12345678, full_domain: 'mytest3.demo.ecoworkinc.com.', status: 1}
      isSuccess = db.db_ddns_session_update(data)
      expect(isSuccess).to be true
      
      access = db.db_ddns_session_access({id: ddns_session_id})
      expect(access.status.to_d).to eq(1)
    end
    
    it 'Delete DDNS Session record' do
      isSuccess = db.db_ddns_session_delete(ddns_session_id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_ddns_session_delete(0)
      expect(isSuccess).to be false
    end
  end
  
  context "About User info access" do
    
    it 'Retrieve user local by device id' do
      user_local = db.db_retrive_user_local_by_device_id('123456789')
      expect(user_local).to be_an_instance_of(String)
    end
    
    it 'Retrieve user email by DDNS Session id' do
      user_email = db.db_retrive_user_email_by_ddns_session_id(1)
      expect(user_email).to be_an_instance_of(String)
    end
    
    it 'Retrieve user email by XMPP account' do
      user_email = db.db_retrive_user_email_by_xmpp_account('bot2')
      expect(user_email).to be_an_instance_of(String)
    end
  end
  
  ddns_retry_session_id = nil
  ddns_retry_data = {device_id: 123456789, full_domain: 'test123.demo.ecoworokinc.com.'}
  
  context "About DDNS Retry Session table" do
    it 'Access non-exist record from DDNS Retry Session table' do
      ddns = db.db_ddns_retry_session_access({id: 0})
      expect(ddns).to be_nil
    end
    
    it 'Add new record into DDNS Retry Session table' do
      
      ddns = db.db_ddns_retry_session_insert(ddns_retry_data)
      expect(ddns).not_to be_nil
      ddns_retry_session_id = ddns.id
    end
    
    it 'Update DDNS Retry Session record' do
      ddns_retry_data[:id] = ddns_retry_session_id
      isSuccess = db.db_ddns_retry_session_update(ddns_retry_data)
      expect(isSuccess).to be true
    end
    
    it 'Access all retry DDNS session' do
      ddnss = db.db_retrive_retry_ddns
      expect(ddnss).not_to be_nil
    end
    
    it 'Delete DDNS Retry Session record' do
      isSuccess = db.db_ddns_retry_session_delete(ddns_retry_session_id)
      expect(isSuccess).to be true
    end
  end
end