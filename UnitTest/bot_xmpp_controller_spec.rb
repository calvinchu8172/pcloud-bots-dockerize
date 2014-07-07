require_relative '../lib/bot_xmpp_controller'
require_relative '../lib/bot_route_access'
require_relative '../lib/bot_db_access'
require_relative './bot_xmpp_spec_protocol_template'
require 'aws-sdk'
require 'xmpp4r/client'
require 'multi_xml'
include Jabber

DELAY_TIME = 0.5

Jabber::debug = FALSE

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
    client.add_message_callback do |msg|
      x = msg.respond_to?(:x) && !msg.x.nil? ? msg.x : msg.to_s
    end
  }
  callbackThread.abort_on_exception = TRUE
  
  context "Send request methods test" do
    it 'Send PAIR START REQUEST message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KPAIR_START_REQUEST, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      action = xml['x']['field']['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('start')
    end
  
    x = nil
    it 'Send PAIR COMPLETED SUCCESS RESPONSE message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, email: 'example@ecoworkinc.com', session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field'][0]['value']
      expect(action).to eq('completed')
    end
    
    x = nil
    it 'Send PAIR COMPLETED FAILURE RESPONSE message to device' do
      session_id = 1
      error_code = 999
      
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field'][0]['value']
      error = xml['x']['field'][1]['value']
      expect(action).to eq('completed')
      expect(error.to_d).to eq(error_code)
    end
    
    x = nil
    it 'Send PAIR TIMEOUT SUCCESS RESPONSE message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KPAIR_TIMEOUT_SUCCESS_RESPONSE, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field']['value']
      expect(action).to eq('cancel')
    end
    
    x = nil
    it 'Send PAIR TIMEOUT FAILURE FAILURE message to device' do
      session_id = 1
      error_code = 998
      
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      action = xml['x']['field'][0]['value']
      error = xml['x']['field'][1]['value']
      expect(action).to eq('cancel')
      expect(error.to_d).to eq(error_code)
    end
    
    x = nil
    it 'Send UNPAIR ASK REQUEST message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KUNPAIR_ASK_REQUEST, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('unpair')
    end
    
    x = nil
    it 'Send UPNP ASK REQUEST message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, language: 'en', session_id: session_id}
      XMPPController.send_request(KUPNP_ASK_REQUEST, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      subject = xml['message']['subject']
      expect(subject).to eq('upnp_service')
    end
    
    x = nil
    it 'Send KUPNP SETTING REQUEST message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, language: 'en', field_item: '', session_id: session_id}
      XMPPController.send_request(KUPNP_SETTING_REQUEST, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('upnp_service')
    end
    
    x = nil
    it 'Send DDNS SETTING REQUEST message to device' do
      session_id = 1
      host_name = 'mytest3'
      domain_name = 'demo.ecoworkinc.com.'
      full_domain = host_name + '.' + domain_name
      
      info = {xmpp_account: device_xmpp_account, session_id: session_id, ip: '10.1.1.111', full_domain: full_domain}
      XMPPController.send_request(KDDNS_SETTING_REQUEST, info)
      sleep(10)
      
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
    end
    
    x = nil
    it 'Send DDNS SETTING SUCCESS RESPONSE message to device' do
      session_id = 1
      
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
      sleep(DELAY_TIME)
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      type = xml['x']['type']
      expect(title).to eq('config')
      expect(type).to eq('result')
    end
    
    x = nil
    it 'Send DDNS SETTING FAILURE RESPONSE message to device' do
      session_id = 1
      error_code = 997
      
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
      sleep(DELAY_TIME)
      
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
    
  end
end
