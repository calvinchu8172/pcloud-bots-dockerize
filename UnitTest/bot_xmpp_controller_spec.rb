require_relative '../lib/bot_xmpp_controller'
require_relative '../lib/bot_route_access'
require_relative '../lib/bot_db_access'
require_relative '../lib/bot_pair_protocol_template'
require_relative './bot_xmpp_spec_protocol_template'
require 'aws-sdk'
require 'xmpp4r/client'
require 'multi_xml'
require 'json'
require 'eventmachine'
include Jabber

DELAY_TIME = 0.5

Jabber::debug = FALSE

def valid_json? json_
  JSON.parse(json_)
  return true
rescue JSON::ParserError
  return false
end

describe XMPPController do
  
  config_file = File.join(File.dirname(__FILE__), BOT_ACCOUNT_CONFIG_FILE)
  config = YAML.load(File.read(config_file))
  
  bot_xmpp_account = config['bot_xmpp_account']
  device_xmpp_account = 'bot3@xmpp.pcloud.ecoworkinc.com/device'
  jid = JID.new(device_xmpp_account)
  client = Client.new(jid)
  
  let(:route) {BotRouteAccess.new}
  let(:db) {BotDBAccess.new}
  
  xmppThread=Thread.new{
    XMPPController.new
    XMPPController.run
  }
  xmppThread.abort_on_exception = TRUE
  sleep(10)
  
  it 'Config file check' do
    expect(config).to be_an_instance_of(Hash)
    
    expect(config).to have_key('bot_xmpp_account')
    expect(config).to have_key('bot_xmpp_password')
    
    expect(config['bot_xmpp_account']).not_to eq('xxx')
    expect(config['bot_xmpp_password']).not_to eq('xxx')
  end
  
  it 'Connection to remote XMPP server' do
    client.connect
    isAuth = client.auth('12345')
    expect(isAuth).to be true
  end
  
  x = nil
  callbackThread = Thread.new{
    EM.run{
      client.add_message_callback do |msg|
        x = msg.respond_to?(:x) && !msg.x.nil? ? msg.x : msg.to_s
      end
    }
  }
  callbackThread.abort_on_exception = TRUE
  
  context "Send request methods test" do
    it 'Send PAIR START REQUEST message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KPAIR_START_REQUEST, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      action = xml['x']['field']['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('start')
    end
  
    it 'Send PAIR COMPLETED SUCCESS RESPONSE message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, email: 'example@ecoworkinc.com', session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field'][0]['value']
      expect(action).to eq('completed')
    end
    
    it 'Send PAIR COMPLETED FAILURE RESPONSE message to device' do
      session_id = 1
      error_code = 999
      
      x = nil
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field'][0]['value']
      error = xml['x']['field'][1]['value']
      expect(action).to eq('completed')
      expect(error.to_d).to eq(error_code)
    end
    
    it 'Send PAIR TIMEOUT SUCCESS RESPONSE message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KPAIR_TIMEOUT_SUCCESS_RESPONSE, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field']['value']
      expect(action).to eq('cancel')
    end
    
    it 'Send PAIR TIMEOUT FAILURE FAILURE message to device' do
      session_id = 1
      error_code = 998
      
      x = nil
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field'][0]['value']
      error = xml['x']['field'][1]['value']
      expect(action).to eq('cancel')
      expect(error.to_d).to eq(error_code)
    end
    
    it 'Send UNPAIR ASK REQUEST message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KUNPAIR_ASK_REQUEST, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('unpair')
      
      sleep(60)
    end
    
    it 'Send UPNP ASK REQUEST message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, language: 'en', session_id: session_id}
      XMPPController.send_request(KUPNP_ASK_REQUEST, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      subject = xml['message']['subject']
      expect(subject).to eq('upnp_service')
    end
    
    it 'Send KUPNP SETTING REQUEST message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, language: 'en', field_item: '', session_id: session_id}
      XMPPController.send_request(KUPNP_SETTING_REQUEST, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('upnp_service')
    end
    
    it 'Send DDNS SETTING REQUEST message to device' do
      session_id = 1
      host_name = 'mytest3'
      domain_name = 'demo.ecoworkinc.com.'
      full_domain = host_name + '.' + domain_name
      
      x = nil
      info = {xmpp_account: device_xmpp_account, session_id: session_id, ip: '10.1.1.111', full_domain: full_domain}
      XMPPController.send_request(KDDNS_SETTING_REQUEST, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      hostname_prefix = xml['x']['field'][0]['value']
      hostname_suffix = xml['x']['field'][1]['value']
      expect(title).to eq('config')
      expect(hostname_prefix).to eq(host_name)
      expect(hostname_suffix).to eq(domain_name)
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
      
      sleep(60)
    end
    
    it 'Send DDNS SETTING SUCCESS RESPONSE message to device' do
      session_id = 1
      
      x = nil
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      type = xml['x']['type']
      expect(title).to eq('config')
      expect(type).to eq('result')
    end
    
    it 'Send DDNS SETTING FAILURE RESPONSE message to device' do
      session_id = 1
      error_code = 997
      
      x = nil
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error.to_d).to eq(error_code)
    end
  end
  
  context 'Receive RESULT message' do
    it 'Receive PAIR START SUCCESS response' do
      data = {user_id: 2, device_id: 123456789}
      pair_session = db.db_pairing_session_insert(data[:user_id], data[:device_id])
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 0
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      msg = PAIR_START_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      pair_session = db.db_pairing_session_access({id: session_id})
      expect(pair_session).not_to be_nil
      expect(pair_session.status.to_d).to eq(1)
      isSuccess = db.db_pairing_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive UNPAIR SUCCESS response' do
      data = {device_id: 123456789}
      unpair_session = db.db_unpair_session_insert(data)
      expect(unpair_session).not_to be_nil
      session_id = unpair_session.id
      
      msg = UNPAIR_RESPONSE_SUCCESS % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      unpair_session = db.db_unpair_session_access({id: session_id})
      expect(unpair_session).to be_nil
    end
    
    it 'Receive UPNP SET SUCCESS response' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: '{}'}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
      
      msg = UPNP_ASK_RESPONSE_SUCCESS % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(4)
      
      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS SETTINGS SUCCESS message' do
      data = {device_id: 1234567, full_domain: 'test3.demo.ecoworkinc.com', status:1}
      ddns_session = db.db_ddns_session_insert(data)
      expect(ddns_session).not_to be_nil
      session_id = ddns_session.id
      
      msg = DDNS_SETTING_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      ddns_session = db.db_ddns_session_access({id: session_id})
      expect(ddns_session.status.to_d).to eq(2)
      
      isSuccess = db.db_ddns_session_delete(session_id)
      expect(isSuccess).to be true
    end
  end
  
  context 'Receive SUBMIT message' do
    
    it 'Receive PAIR COMPLETED SUCCESS response' do
      data = {user_id: 2, device_id: 123456789}
      pair_session = db.db_pairing_session_insert(data[:user_id], data[:device_id])
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      x = nil
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      pair_session = db.db_pairing_session_access({id: session_id})
      expect(pair_session).not_to be_nil
      expect(pair_session.status.to_d).to eq(2)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      value = xml['x']['field'][0]['value']
      expect(title).to eq('pair')
      expect(value).to eq('completed')
      
      data[:expire_at] = DateTime.strptime((Time.now.to_i - 240).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      x = nil
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      pair_session = db.db_pairing_session_access({id: session_id})
      expect(pair_session).not_to be_nil
      expect(pair_session.status.to_d).to eq(4)
      
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      value = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']
      expect(title).to eq('pair')
      expect(value).to eq('completed')
      expect(error_code.to_d).to eq(899)
      
      isSuccess = db.db_pairing_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive PAIR COMPLETED FAILURE response' do
      data = {user_id: 2, device_id: 123456789}
      pair_session = db.db_pairing_session_insert(data[:user_id], data[:device_id])
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      x = nil
      msg = PAIR_TIMEOUT_REQUEST % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      pair_session = db.db_pairing_session_access({id: session_id})
      expect(pair_session).not_to be_nil
      expect(pair_session.status.to_d).to eq(4)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      cancel = xml['x']['field']['value']
      expect(title).to eq('pair')
      expect(cancel).to eq('cancel')
      
      x = nil
      msg = PAIR_TIMEOUT_REQUEST % [bot_xmpp_account, device_xmpp_account, 0]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      cancel = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']
      expect(title).to eq('pair')
      expect(cancel).to eq('cancel')
      expect(error_code.to_d).to eq(898)
      
      isSuccess = db.db_pairing_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    host_name = 'test123'
    domain_name = 'demo.ecoworkinc.com.'
    
    it 'Receive DDNS SETTING error response, code - 998, ip not found' do
      session_id = 0
      
      x = nil
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(998)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, DNS format error' do
      session_id = 0
      
      x = nil
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, '', domain_name, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 995, domain has been used' do
      session_id = 0
      
      data = {device_id: 76543210, ip_address: '10.1.1.111', full_domain: host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      expect(ddns).not_to be_nil
      
      data = {device_id: 987654321, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(995)
      
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_device_session_delete(device.id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS SETTING error response, code - 996, has registered' do
      session_id = 0
      
      data = {device_id: 987654321, ip_address: '10.1.1.111', full_domain: host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      expect(ddns).not_to be_nil
      
      data = {device_id: 987654321, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(996)
      
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_device_session_delete(device.id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS SETTING SUCCESS response' do
      session_id = 0
      
      data = {device_id: 987654321, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil?
        sleep(0.1)
      end
      
      ddns = db.db_ddns_access({full_domain: host_name + '.' + domain_name})
      expect(ddns).not_to be_nil
      expect(ddns.device_id.to_d).to eq(data[:device_id])
      expect(ddns.ip_address).to eq(data[:ip])
      
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('config')
      
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_device_session_delete(device.id)
      expect(isSuccess).to be true
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
    end
  end
  
  context 'Receive CANCEL message' do
    
    it 'Receive PAIR FAILURE response' do
      data = {user_id: 2, device_id: 123456789}
      pair_session = db.db_pairing_session_insert(data[:user_id], data[:device_id])
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      msg = PAIR_START_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      pair_session = db.db_pairing_session_access({id: session_id})
      expect(pair_session).not_to be_nil
      expect(pair_session.status.to_d).to eq(4)
      
      isSuccess = db.db_pairing_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive UNPAIR FAILURE response' do
      data = {device_id: 123456789}
      unpair_session = db.db_unpair_session_insert(data)
      expect(unpair_session).not_to be_nil
      session_id = unpair_session.id
      
      msg = UNPAIR_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      unpair_session = db.db_unpair_session_access({id: session_id})
      expect(unpair_session).to be_nil
    end
    
    it 'Receive UPNP FAILURE response' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: '{}'}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
      
      msg = UPNP_ASK_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(3)
      
      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS FAILURE response' do
      host_name = 'mytest3'
      domain_name = 'demo.ecoworkinc.com.'
      
      data = {device_id: 987654321, full_domain: host_name + '.' + domain_name, status: 0}
      ddns_session = db.db_ddns_session_insert(data)
      expect(ddns_session).not_to be_nil
      session_id = ddns_session.id
      
      msg = DDNS_SETTING_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      ddns_session = db.db_ddns_session_access({id: session_id})
      expect(ddns_session).not_to be_nil
      expect(ddns_session.status.to_d).to eq(3)
      
      isSuccess = db.db_ddns_session_delete(session_id)
      expect(isSuccess).to be true
    end
  end
  
  context 'Receive FORM message' do
    
    it 'Receive UPNP service list' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: ''}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
      
      msg = UPNP_ASK_RESPONSE % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(1)
      
      isValid = valid_json? upnp_session.service_list.to_s
      expect(isValid).to be true
      
      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
  end
end