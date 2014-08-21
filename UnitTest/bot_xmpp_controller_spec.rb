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
require 'resolv'
include Jabber

DELAY_TIME = 0.5

FLUENT_BOT_SYSINFO = "bot.sys-info"
FLUENT_BOT_SYSERROR = "bot.sys-error"
FLUENT_BOT_SYSALERT = "bot.sys-alert"
FLUENT_BOT_FLOWINFO = "bot.flow-info"
FLUENT_BOT_FLOWERROR = "bot.flow-error"
FLUENT_BOT_FLOWALERT = "bot.flow-alert"

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
  device_xmpp_account_node = 'bot3'
  jid = JID.new(device_xmpp_account)
  client = Client.new(jid)
  
  host_name = 'test%d' % Time.now.to_i
  domain_name = 'demo.ecoworkinc.com.'
  
  let(:route) {BotRouteAccess.new}
  let(:db) {BotDBAccess.new}
  
  xmpp_connect_ready = FALSE
  
  xmppThread=Thread.new{
    XMPPController.new
    XMPPController.run
  }
  xmppThread.abort_on_exception = TRUE
  
  XMPPController.when_ready { xmpp_connect_ready = TRUE }
  
  while !xmpp_connect_ready
    puts '    Waiting XMPP connection ready'
    sleep(2)
  end
  puts '    XMPP connection ready'
  
  it 'Config file check' do
    expect(config).to be_an_instance_of(Hash)
    
    expect(config).to have_key('bot_xmpp_account')
    expect(config).to have_key('bot_xmpp_password')
    
    expect(config['bot_xmpp_account']).not_to eq('xxx')
    expect(config['bot_xmpp_password']).not_to eq('xxx')
  end
  
  it 'Connection to remote XMPP server' do
    client.connect
    sleep(3)
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
      i = 0
      info = {xmpp_account: device_xmpp_account_node, session_id: session_id}
      XMPPController.send_request(KPAIR_START_REQUEST, info)
      while x.nil? && i < 100
        sleep(0.1)
        i+=1
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
      i = 0
      info = {xmpp_account: device_xmpp_account, email: 'example@ecoworkinc.com', session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_FAILURE_RESPONSE, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KPAIR_TIMEOUT_SUCCESS_RESPONSE, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KPAIR_TIMEOUT_FAILURE_RESPONSE, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      unpair_session_id = 1
      host_name = 'mytest3'
      domain_name = 'demo.ecoworkinc.com.'
      ip = '10.1.1.112'
      ipv4 = nil
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      ddns = db.db_ddns_insert({device_id: 123456789, full_domain: host_name + '.' + domain_name, ip_address: ip})
      expect(ddns).not_to be_nil
      
      ddns_session_id = ddns.id
      isSuccess = route.create_record({host_name: host_name, domain_name: domain_name, ip: ip})
      expect(isSuccess).to be true
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node,
              full_domain: host_name + '.' + domain_name,
              session_id: unpair_session_id}
      
      XMPPController.send_request(KUNPAIR_ASK_REQUEST, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_nil
      resolv_i.close
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('unpair')
      
      ddns_confirm = db.db_ddns_access({id: ddns_session_id})
      expect(ddns_confirm).to be_nil
      
      sleep(10)
    end
    
    it 'Send UPNP ASK REQUEST message to device' do
      session_id = 1
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, language: 'en', session_id: session_id}
      XMPPController.send_request(KUPNP_ASK_REQUEST, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('get_upnp_service')
    end
    
    it 'Send KUPNP SETTING REQUEST message to device' do
      session_id = 1
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, language: 'en', field_item: '', session_id: session_id}
      XMPPController.send_request(KUPNP_SETTING_REQUEST, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('set_upnp_service')
    end
    
    it 'Send DDNS SETTING REQUEST message to device for create new DDNS record' do
      
      device_id = 987654321
      host_name = 'test%d' % Time.now.to_i
      full_domain = host_name + '.' + domain_name
      
      data = {device_id: device_id, full_domain: full_domain, status: 0}
      ddns_session = db.db_ddns_session_insert(data)
      expect(ddns_session).not_to be_nil
      session_id = ddns_session.id
      ipv4 = nil
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, session_id: session_id, ip: '10.1.1.111', full_domain: full_domain, device_id: 987654321}
      XMPPController.send_request(KDDNS_SETTING_REQUEST, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      j = 60
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      hostname_prefix = xml['x']['field'][0]['value']
      hostname_suffix = xml['x']['field'][1]['value']
      expect(title).to eq('config')
      expect(hostname_prefix).to eq(host_name)
      expect(hostname_suffix).to eq(domain_name)
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_nil
      resolv_i.close
      
      ddns = db.db_ddns_access({full_domain: full_domain})
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_ddns_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Send DDNS SETTING REQUEST message to device for update DDNS record' do
      device_id = 987654321
      old_host_name = 'test%d' % Time.now.to_i
      
      sleep(0.2)
      
      host_name = 'test%d' % Time.now.to_i
      full_domain = host_name + '.' + domain_name
      session_id = nil
      ddns_id = nil
      ipv4 = nil
      
      data = {device_id: device_id, full_domain: full_domain, status: 0}
      ddns_session = db.db_ddns_session_insert(data)
      expect(ddns_session).not_to be_nil
      session_id = ddns_session.id
      
      data = {device_id: device_id, ip_address: '10.1.1.110', full_domain: old_host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      expect(ddns).not_to be_nil
      ddns_id = ddns.id
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, session_id: session_id, ip: '10.1.1.111', full_domain: full_domain, device_id: 987654321}
      XMPPController.send_request(KDDNS_SETTING_REQUEST, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      j = 60
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      hostname_prefix = xml['x']['field'][0]['value']
      hostname_suffix = xml['x']['field'][1]['value']
      expect(title).to eq('config')
      expect(hostname_prefix).to eq(host_name)
      expect(hostname_suffix).to eq(domain_name)
      
      ddns = db.db_ddns_access({id: ddns_id})
      expect(ddns).not_to be_nil
      expect(ddns.ip_address).to eq('10.1.1.111')
      expect(ddns.full_domain).to eq(full_domain)
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_nil
      resolv_i.close
      
      ddns = db.db_ddns_access({full_domain: full_domain})
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_ddns_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Send DDNS SETTING SUCCESS RESPONSE message to device' do
      session_id = 1
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      data = {user_id: 2, device_id: 123456789, expire_at: DateTime.now}
      pair_session = db.db_pairing_session_insert(data)
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
      data = {user_id: 2, device_id: 123456789, expire_at: DateTime.now}
      pair_session = db.db_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      x = nil
      i = 0
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
    
    it 'Receive PAIR TIMEOUT response' do
      data = {user_id: 2, device_id: 123456789, expire_at: DateTime.now}
      pair_session = db.db_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      x = nil
      i = 0
      msg = PAIR_TIMEOUT_REQUEST % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      msg = PAIR_TIMEOUT_REQUEST % [bot_xmpp_account, device_xmpp_account, 0]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
    
    it 'Receive DDNS SETTING error response, code - 998, ip not found' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, '', domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, DNS too length' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, 'mytest212321321321321321321321321321321321321321312312ssdsdsdsd2', domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, DNS too short' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, 'my', domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, host name has been reserved' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, 'www', domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
      
      host_name = 'test%d' % Time.now.to_i
      data = {device_id: 76543210, ip_address: '10.1.1.111', full_domain: host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      expect(ddns).not_to be_nil
      
      data = {device_id: 987654321, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
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
    
    it 'Receive DDNS SETTING response as DDNS record has been registered' do
      session_id = 0
      
      data = {device_id: 987654321, ip_address: '10.1.1.111', full_domain: host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      expect(ddns).not_to be_nil
      
      data = {device_id: 987654321, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('config')
      
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_device_session_delete(device.id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS SETTING SUCCESS response' do
      session_id = 0
      ipv4 = nil
      
      data = {device_id: 987654321, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      ddns = db.db_ddns_access({full_domain: host_name + '.' + domain_name})
      expect(ddns).not_to be_nil
      expect(ddns.device_id.to_d).to eq(data[:device_id])
      expect(ddns.ip_address).to eq(data[:ip])
      
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('config')
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_nil
      resolv_i.close
      
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_device_session_delete(device.id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS SETTING SUCCESS response for update DDNS record' do
      session_id = 0
      ipv4 = nil
      device_id = 987654321
      old_host_name = 'test%d' % Time.now.to_i
      
      sleep(0.2)
      
      host_name = 'test%d' % Time.now.to_i
      
      data = {device_id: device_id, ip_address: '10.1.1.110', full_domain: old_host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      expect(ddns).not_to be_nil
      
      data = {device_id: device_id, ip: '10.1.1.111', xmpp_account: jid.node, password: '12345'}
      device = db.db_device_session_insert(data)
      expect(device).not_to be_nil
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id]
      client.send msg
      while x.nil? && i < 100
        sleep(0.1)
        i += 1
      end
      
      ddns = db.db_ddns_access({full_domain: host_name + '.' + domain_name})
      expect(ddns).not_to be_nil
      expect(ddns.device_id.to_d).to eq(device_id)
      expect(ddns.ip_address).to eq(data[:ip])
      expect(ddns.full_domain).to eq(host_name + '.' + domain_name)
      
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('config')
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_nil
      resolv_i.close
      
      isSuccess = db.db_ddns_delete(ddns.id)
      expect(isSuccess).to be true
      
      isSuccess = db.db_device_session_delete(device.id)
      expect(isSuccess).to be true
    end
  end
  
  context 'Receive CANCEL message' do
    
    it 'Receive PAIR START FAILURE response' do
      data = {user_id: 2, device_id: 123456789, expire_at: DateTime.now}
      pair_session = db.db_pairing_session_insert(data)
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
    
    it 'Receive PAIR COMPLETED FAILURE response' do
      data = {user_id: 2, device_id: 123456789, expire_at: DateTime.now}
      pair_session = db.db_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      session_id = pair_session.id
      
      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true
      
      msg = PAIR_COMPLETED_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      pair_session = db.db_pairing_session_access({id: session_id})
      expect(pair_session).not_to be_nil
      expect(pair_session.status.to_d).to eq(4)
      
      isSuccess = db.db_pairing_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive PAIR CANCEL FAILURE response' do
      data = {user_id: 2, device_id: 123456789, expire_at: DateTime.now}
      pair_session = db.db_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      session_id = pair_session.id

      data[:id] = session_id
      data[:status] = 1
      data[:expire_at] = DateTime.strptime((Time.now.to_i + 120).to_s, "%s")
      isSuccess = db.db_pairing_session_update(data)
      expect(isSuccess).to be true

      msg = PAIR_TIMEOUT_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
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
    
    it 'Receive UPNP GET FAILURE response' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: '{}'}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
      
      msg = UPNP_ASK_GET_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(3)

      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end

    it 'Receive UPNP SET FAILURE response' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: '[{"service_name":"FTP","status":true,"enabled":true,"description":"FTP configuration", "error_code":""},{"service_name":"DDNS","status":true,"enabled":false,"description":"DDNS configuration", "error_code":""},{"service_name":"HTTP","status":true,"enabled":false,"description":"HTTP configuration", "error_code":""}]'}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
      
      msg = UPNP_ASK_SET_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(1)

      service_list = JSON.parse(upnp_session.service_list.to_s)
      expect(service_list[0]['error_code']).to eq('799')
      expect(service_list[1]['error_code']).to eq('')
      expect(service_list[2]['error_code']).to eq('798')

      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive UPNP SET FAILURE response - single item' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: '[{"service_name":"FTP","status":true,"enabled":true,"description":"FTP configuration", "error_code":""},{"service_name":"DDNS","status":true,"enabled":false,"description":"DDNS configuration", "error_code":""},{"service_name":"HTTP","status":true,"enabled":false,"description":"HTTP configuration", "error_code":""}]'}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id

      msg = UPNP_ASK_SET_RESPONSE_FAILURE_SINGLE_ITEM % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(1)

      service_list = JSON.parse(upnp_session.service_list.to_s)
      expect(service_list[0]['error_code']).to eq('799')
      expect(service_list[1]['error_code']).to eq('')
      expect(service_list[2]['error_code']).to eq('')

      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive DDNS FAILURE response' do
      host_name = 'test%d' % Time.now.to_i
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
      service_list = JSON.parse(upnp_session.service_list.to_s)
      expect(service_list[0].has_key?("service_name")).to be true
      expect(service_list[0].has_key?("status")).to be true
      expect(service_list[0].has_key?("enabled")).to be true
      expect(service_list[0].has_key?("description")).to be true
      expect(service_list[0].has_key?("path")).to be true
      expect(service_list[0].has_key?("error_code")).to be true
      
      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive UPNP service list - single item' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: ''}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
 
      msg = UPNP_ASK_RESPONSE_SINGLE_ITEM % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
 
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(1)

      isValid = valid_json? upnp_session.service_list.to_s
      expect(isValid).to be true
      service_list = JSON.parse(upnp_session.service_list.to_s)
      expect(service_list[0].has_key?("service_name")).to be true
      expect(service_list[0].has_key?("status")).to be true
      expect(service_list[0].has_key?("enabled")).to be true
      expect(service_list[0].has_key?("description")).to be true
      expect(service_list[0].has_key?("path")).to be true
      expect(service_list[0].has_key?("error_code")).to be true

      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
    
    it 'Receive UPNP service list - empty form' do
      data = {device_id: 1234567, user_id: 2, status:0, service_list: '[{"service_name":"FTP","status":true,"enabled":true,"description":"FTP configuration", "error_code":""},{"service_name":"DDNS","status":true,"enabled":false,"description":"DDNS configuration", "error_code":""},{"service_name":"HTTP","status":true,"enabled":false,"description":"HTTP configuration", "error_code":""}]'}
      upnp_session = db.db_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      session_id = upnp_session.id
      
      msg = UPNP_ASK_EMPTY_RESPONSE % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = db.db_upnp_session_access({id: session_id})
      expect(upnp_session).not_to be_nil
      expect(upnp_session.status.to_d).to eq(1)
      
      isValid = valid_json? upnp_session.service_list.to_s
      expect(isValid).to be false
      
      isSuccess = db.db_upnp_session_delete(session_id)
      expect(isSuccess).to be true
    end
  end
  
  context 'Other Methods' do
    it 'Retry register DDNS' do
      host_name = 'test%d' % Time.now.to_i
      domain_name = 'demo.ecoworkinc.com.'
      data = {device_id: 123456789, full_domain: host_name + '.' + domain_name}
      ipv4 = nil
      retry_session = db.db_ddns_retry_session_insert(data)
      expect(retry_session).not_to be_nil
      
      session_id = retry_session.id
      
      XMPPController.retry_ddns_register
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      
      dns_data = {host_name: host_name, domain_name: domain_name}
      isSuccess = route.delete_record(dns_data)
      expect(isSuccess).to be true
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(host_name + '.' + domain_name)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      expect(ipv4).to be_nil
      resolv_i.close
      
      retry_session = db.db_ddns_retry_session_access({id: session_id})
      expect(retry_session).to be_nil
    end
  end
end
