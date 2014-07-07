require_relative '../lib/bot_xmpp_controller'
require_relative '../lib/bot_route_access'
require_relative '../lib/bot_pair_protocol_template'
require 'aws-sdk'
require 'xmpp4r/client'
require 'multi_xml'
include Jabber

DELAY_TIME = 0.5

Jabber::debug = FALSE

describe XMPPController do
  
  config_file = File.join(File.dirname(__FILE__), BOT_ACCOUNT_CONFIG_FILE)
  config = YAML.load(File.read(config_file))
  
  xmpp_account = 'bot3@xmpp.pcloud.ecoworkinc.com/device'
  jid = JID.new(xmpp_account)
  client = Client.new(jid)
  
  let(:route) {BotRouteAccess.new}
  
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
      
      info = {xmpp_account: xmpp_account, session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, email: 'example@ecoworkinc.com', session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, error_code: error_code, session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, error_code: error_code, session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, language: 'en', session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, language: 'en', field_item: '', session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, session_id: session_id, ip: '10.1.1.111', full_domain: full_domain}
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
      
      info = {xmpp_account: xmpp_account, session_id: session_id}
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
      
      info = {xmpp_account: xmpp_account, error_code: error_code, session_id: session_id}
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
    it '' do
      
    end
    
  end
end
