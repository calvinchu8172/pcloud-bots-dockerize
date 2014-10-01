require_relative '../lib/bot_xmpp_controller'
require_relative '../lib/bot_route_access'
require_relative '../lib/bot_db_access'
require_relative '../lib/bot_unit'
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

KPAIR_WAITING_EXPIRE_TIME = 20.0
KUPNP_EXPIRE_TIME = 20.0

Jabber::debug = FALSE

describe XMPPController do
  bot_xmpp_account = 'bot7@localhost/robot'
  bot_xmpp_password = '12345'
  device_xmpp_account = 'bot8@localhost/device'
  device_xmpp_account_node = 'bot8'
  device_xmpp_password = '12345'
  jid = JID.new(device_xmpp_account)
  client = Client.new(jid)
  
  host_name = 'ut%d' % Time.now.to_i
  domain_name = 'demo.ecoworkinc.com.'
  
  let(:route) {BotRouteAccess.new}
  let(:db) {BotDBAccess.new}
  let(:rd) {BotRedisAccess.new}
  
  xmpp_connect_ready = FALSE
  
  xmppThread=Thread.new{
    XMPPController.new(bot_xmpp_account, bot_xmpp_password)
    XMPPController.run
  }
  xmppThread.abort_on_exception = TRUE
  
  XMPPController.when_ready { xmpp_connect_ready = TRUE }
  
  while !xmpp_connect_ready
    puts '    Waiting XMPP connection ready'
    sleep(2)
  end
  puts '    XMPP connection ready'
  
  it 'Connection to remote XMPP server' do
    client.connect
    sleep(3)
    isAuth = client.auth(device_xmpp_password)
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
      device_id = Time.now.to_i
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, device_id: device_id}
      XMPPController.send_request(KPAIR_START_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      action = xml['x']['field'][0]['value']
      timeout = xml['x']['field'][1]['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('start')
      expect(timeout.to_i).to eq(600)
    end

    it 'Send PAIR COMPLETED SUCCESS RESPONSE message to device' do
      session_id = 1
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, email: 'example@ecoworkinc.com', session_id: session_id}
      XMPPController.send_request(KPAIR_COMPLETED_SUCCESS_RESPONSE, info)
      while x.nil? && i < 200
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
      while x.nil? && i < 200
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
    
    it 'Send PAIR TIMEOUT REQUEST message to device' do
      device_id = Time.now.to_i
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, title: 'pair', tag: device_id}
      XMPPController.send_request(KSESSION_TIMEOUT_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      action = xml['x']['field']['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('timeout')
    end

    it 'Send PAIR CANCEL REQUEST message to device' do
      device_id = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, title: 'pair', tag: device_id}
      XMPPController.send_request(KSESSION_CANCEL_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      action = xml['x']['field']['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('cancel')
    end
    
    it 'Send PAIR CANCEL SUCCESS RESPONSE message to device' do
      device_id = Time.now.to_i
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, title: 'pair', tag: device_id}
      XMPPController.send_request(KSESSION_CANCEL_SUCCESS_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      action = xml['x']['field']['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('cancel')
    end

    it 'Send PAIR CANCEL FAILURE RESPONSE message to device' do
      device_id = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, title: 'pair', error_code: 799, tag: device_id}
      XMPPController.send_request(KSESSION_CANCEL_FAILURE_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      action = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(action).to eq('cancel')
      expect(error_code.to_i).to eq(799)
    end
    
    it 'Send UNPAIR ASK REQUEST message to device' do
      index = Time.now.to_i
      full_domain = "ut%d.demo.ecoworkinc.com." % index
      ip = '10.1.1.112'
      device_id = index
      ipv4 = nil
      
      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      
      ddns = db.db_ddns_insert({device_id: device_id, full_domain: full_domain, ip_address: ip})

      index = rd.rd_ddns_session_index_get
      batch_data = {index: index, device_id: device_id, full_domain: full_domain, ip: ip, action: 'update', hasMailed: false}
      isCreated = rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
      
      expect(isCreated).to be true
      
      i = 0
      while ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(full_domain)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      ipv4_created = ipv4
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node,
              full_domain: full_domain,
              session_id: device_id}
      
      XMPPController.send_request(KUNPAIR_ASK_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      i = 0
      while !ipv4.nil?
        begin
          ipv4 = resolv_i.getaddress(full_domain)
        rescue Resolv::ResolvError => error
          ipv4 = nil
          puts '        ' + error.to_s
        end
        sleep(1)
        i += 1
        break if i > 120
      end
      
      ipv4_deleted = ipv4
      resolv_i.close
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      title = xml['x']['title']
      
      ddns_confirm = db.db_ddns_access({id: ddns.id})

      expect(ddns).not_to be_nil
      expect(ipv4_created).to be_an_instance_of(Resolv::IPv4)
      expect(ipv4_deleted).to be_nil
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('unpair')
      expect(ddns_confirm).to be_nil
      
      sleep(10)
    end
    
    it 'Send UPNP SET CANCEL REQUEST message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, title: 'set_upnp_service', tag: index}
      XMPPController.send_request(KSESSION_CANCEL_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('set_upnp_service')
      expect(action).to eq('cancel')
    end

    it 'Send UPNP SET CANCEL SUCCESS RESPONSE message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, title: 'set_upnp_service', tag: index}
      XMPPController.send_request(KSESSION_CANCEL_SUCCESS_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('set_upnp_service')
      expect(action).to eq('cancel')
    end

    it 'Send UPNP SET CANCEL FAILURE RESPONSE message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, title: 'set_upnp_service', error_code: 799, tag: index}
      XMPPController.send_request(KSESSION_CANCEL_FAILURE_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('set_upnp_service')
      expect(action).to eq('cancel')
      expect(error_code.to_i).to eq(799)
    end

    it 'Send UPNP GET CANCEL REQUEST message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, title: 'get_upnp_service', tag: index}
      XMPPController.send_request(KSESSION_CANCEL_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('get_upnp_service')
      expect(action).to eq('cancel')
    end

    it 'Send UPNP GET CANCEL SUCCESS RESPONSE message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, title: 'get_upnp_service', tag: index}
      XMPPController.send_request(KSESSION_CANCEL_SUCCESS_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('get_upnp_service')
      expect(action).to eq('cancel')
    end

    it 'Send UPNP GET CANCEL FAILURE RESPONSE message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, title: 'get_upnp_service', error_code: 799, tag: index}
      XMPPController.send_request(KSESSION_CANCEL_FAILURE_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('get_upnp_service')
      expect(action).to eq('cancel')
      expect(error_code.to_i).to eq(799)
    end

    it 'Send UPNP GETTING REQUEST message to device' do
      session_id = 1
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, language: 'en', session_id: session_id}
      XMPPController.send_request(KUPNP_ASK_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('get_upnp_service')
    end

    it 'Send UPNP GETTING REQUEST message to device, waiting timeout test' do
      index = Time.now.to_i
      device_id = index

      data = {device_id: device_id, ip: '10.1.1.110', xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {index: index, user_id: 1, device_id: device_id, status: KSTATUS_START, service_list: '', lan_ip: ''}
      upnp = rd.rd_upnp_session_insert(data)

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, language: 'en', field_item: '', session_id: index}
      XMPPController.send_request(KUPNP_ASK_REQUEST, info)

      j = 25
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'

      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      upnp = rd.rd_upnp_session_access(index)
      isDeletedUPNP = rd.rd_upnp_session_delete(index)
      isDeletedDevice = rd.rd_device_session_delete(device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(isDeletedUPNP).to be true
      expect(isDeletedDevice).to be true
      expect(device).not_to be_nil
      expect(upnp).not_to be_nil
      expect(upnp["status"]).to eq('timeout')
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('get_upnp_service')
      expect(action).to eq('timeout')
    end

    it 'Send UPNP GETTING TIMEOUT REQUEST message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, title: 'get_upnp_service', tag: index}
      XMPPController.send_request(KSESSION_TIMEOUT_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('get_upnp_service')
      expect(action).to eq('timeout')
    end
    
    it 'Send UPNP SETTING REQUEST message to device' do
      session_id = 1
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, language: 'en', field_item: '', session_id: session_id}
      XMPPController.send_request(KUPNP_SETTING_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      expect(title).to eq('set_upnp_service')
    end
    
    it 'Send UPNP SETTING REQUEST message to device, waiting timeout test' do
      index = Time.now.to_i
      device_id = index

      data = {device_id: device_id, ip: '10.1.1.110', xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {index: index, user_id: 1, device_id: device_id, status: KSTATUS_SUBMIT, service_list: '', lan_ip: ''}
      upnp = rd.rd_upnp_session_insert(data)

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, language: 'en', field_item: '', session_id: index}
      XMPPController.send_request(KUPNP_SETTING_REQUEST, info)

      j = 25
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'

      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      upnp = rd.rd_upnp_session_access(index)
      isDeletedUPNP = rd.rd_upnp_session_delete(index)
      isDeletedDevice = rd.rd_device_session_delete(device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(isDeletedUPNP).to be true
      expect(isDeletedDevice).to be true
      expect(device).not_to be_nil
      expect(upnp).not_to be_nil
      expect(upnp["status"]).to eq('timeout')
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('set_upnp_service')
      expect(action).to eq('timeout')
    end

    it 'Send UPNP SETTING TIMEOUT REQUEST message to device' do
      index = Time.now.to_i

      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, title: 'set_upnp_service', tag: index}
      XMPPController.send_request(KSESSION_TIMEOUT_REQUEST, info)
      while x.nil? && i < 200
        sleep(0.1)
        i+=1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('set_upnp_service')
      expect(action).to eq('timeout')
    end

    it 'Send DDNS SETTING REQUEST message to device for create new DDNS record' do
      index = Time.now.to_i
      device_id = index
      host_name = 'ut%d' % index
      full_domain = host_name + '.' + domain_name
      ip = '10.100.1.111'
      
      data = {device_id: device_id, ip: ip, xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {index: index, device_id: device_id, host_name: host_name, domain_name: domain_name, status: KSTATUS_START}
      ddns_session = rd.rd_ddns_session_insert(data)

      session_id = index
      ipv4 = nil
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, session_id: session_id, ip: ip, full_domain: full_domain, device_id: device_id}
      XMPPController.send_request(KDDNS_SETTING_REQUEST, info)
      while x.nil? && i < 200
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
      title = xml['x']['title']
      hostname_prefix = xml['x']['field'][0]['value']
      hostname_suffix = xml['x']['field'][1]['value']
      
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
      
      ipv4_created = ipv4
      
      index = rd.rd_ddns_session_index_get
      batch_data = {index: index, device_id: device_id, full_domain: full_domain, ip: ip, action: 'delete', hasMailed: false}
      isDeleted = rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
      
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
      
      ipv4_deleted = ipv4

      resolv_i.close
      
      ddns = db.db_ddns_access({device_id: device_id, full_domain: full_domain})
      isDeletedDevice = rd.rd_device_session_delete(device_id)
      isDeletedDDNS = db.db_ddns_delete(ddns.id)
      isDeletedDDNSSession = rd.rd_ddns_session_delete(session_id)
      
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('config_ddns')
      expect(hostname_prefix).to eq(host_name)
      expect(hostname_suffix).to eq(domain_name)

      expect(device).not_to be_nil
      expect(ddns_session).not_to be_nil
      expect(ipv4_created).to be_an_instance_of(Resolv::IPv4)
      expect(isDeleted).to be true
      expect(ipv4_deleted).to be_nil
      expect(isDeletedDevice).to be true
      expect(isDeletedDDNS).to be true
      expect(isDeletedDDNSSession).to be true
    end
    
    it 'Send DDNS SETTING REQUEST message to device for update DDNS record' do
      index = Time.now.to_i
      device_id = index
      old_host_name = 'ut%d' % Time.now.to_i
      
      sleep(1.1)
      
      host_name = 'ut%d' % Time.now.to_i
      full_domain = host_name + '.' + domain_name
      ip = '10.100.1.111'
      session_id = nil
      ddns_id = nil
      ipv4 = nil
      
      data = {device_id: device_id, ip: ip, xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)
      
      data = {index: index, device_id: device_id, host_name: host_name, domain_name: domain_name, status: KSTATUS_START}
      ddns_session = rd.rd_ddns_session_insert(data)

      session_id = index

      data = {device_id: device_id, ip_address: ip, full_domain: old_host_name + '.' + domain_name}
      old_ddns = db.db_ddns_insert(data)
      ddns_id = old_ddns.id
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account_node, session_id: session_id, ip: ip, full_domain: full_domain, device_id: device_id}
      XMPPController.send_request(KDDNS_SETTING_REQUEST, info)
      while x.nil? && i < 200
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
      title = nil
      hostname_prefix = nil
      hostname_suffix = nil
      if !xml.nil? then
        title = xml['x']['title']
        hostname_prefix = xml['x']['field'][0]['value']
        hostname_suffix = xml['x']['field'][1]['value']
      end
      
      new_ddns = db.db_ddns_access({id: ddns_id})
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
      
      ipv4_created = ipv4
      
      index = rd.rd_ddns_session_index_get
      batch_data = {index: index, device_id: device_id, full_domain: full_domain, ip: ip, action: 'delete', hasMailed: false}
      isDeleted = rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
      
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
      
      ipv4_deleted = ipv4
      resolv_i.close
      
      ddns = db.db_ddns_access({device_id: device_id, full_domain: full_domain})
      
      isDeletedDDNS = db.db_ddns_delete(ddns.id)
      isDeletedDDNSSession = rd.rd_ddns_session_delete(session_id)

      expect(device).not_to be_nil
      expect(ddns_session).not_to be_nil
      expect(old_ddns).not_to be_nil
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('config_ddns')
      expect(hostname_prefix).to eq(host_name)
      expect(hostname_suffix).to eq(domain_name)
      expect(new_ddns).not_to be_nil
      expect(new_ddns.ip_address).to eq(ip)
      expect(new_ddns.full_domain).to eq(full_domain)
      expect(ipv4_created).to be_an_instance_of(Resolv::IPv4)
      expect(isDeleted).to be true
      expect(ipv4_deleted).to be_nil
      expect(isDeletedDDNS).to be true
      expect(isDeletedDDNSSession).to be true
    end
    
    it 'Send DDNS SETTING SUCCESS RESPONSE message to device' do
      session_id = Time.now.to_i
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_SUCCESS_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      type = xml['x']['type']
      expect(title).to eq('config_ddns')
      expect(type).to eq('result')
    end
    
    it 'Send DDNS SETTING FAILURE RESPONSE message to device' do
      session_id = Time.now.to_i
      error_code = 997
      
      x = nil
      i = 0
      info = {xmpp_account: device_xmpp_account, error_code: error_code, session_id: session_id}
      XMPPController.send_request(KDDNS_SETTING_FAILURE_RESPONSE, info)
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error = xml['x']['field']['value']
      expect(title).to eq('config_ddns')
      expect(error.to_d).to eq(error_code)
    end
  end
  
  context 'Receive RESULT message' do
    it 'Receive PAIR START SUCCESS response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      
      msg = PAIR_START_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      sleep(DELAY_TIME)

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)

      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('waiting')

      expect(hasDeleted).to be true
    end

    it 'Receive PAIR START SUCCESS response, start timeout test' do
      device_id = Time.now.to_i

      data = {device_id: device_id, ip: '10.1.1.110', xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i - 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_insert = rd.rd_pairing_session_insert(data)

      msg = PAIR_START_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      sleep(DELAY_TIME)

      pair_access = rd.rd_pairing_session_access(device_id)
      hasDeletedPair = rd.rd_pairing_session_delete(device_id)
      hasDeletedDevice = rd.rd_device_session_delete(device_id)

      expect(pair_insert).not_to be_nil
      expect(device).not_to be_nil
      expect(pair_access).not_to be_nil
      expect(pair_access["status"]).to eq('timeout')

      expect(hasDeletedPair).to be true
      expect(hasDeletedDevice).to be true
    end
    
    it 'Receive PAIR START SUCCESS response, waiting timeout test' do
      device_id = Time.now.to_i

      data = {device_id: device_id, ip: '10.1.1.110', xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil

      msg = PAIR_START_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      sleep(DELAY_TIME)

      x = nil
      j = 25
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'

      i = 0
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      value = xml['x']['field']['value']

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeletedPair = rd.rd_pairing_session_delete(device_id)
      hasDeletedDevice = rd.rd_device_session_delete(device_id)

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('pair')
      expect(value).to eq('timeout')
      expect(device).not_to be_nil
      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('timeout')
      expect(hasDeletedPair).to be true
      expect(hasDeletedDevice).to be true
    end

    it 'Receive PAIR TIMEOUT SUCCESS response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil

      msg = SESSION_TIMEOUT_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'pair', device_id]
      client.send msg
      sleep(DELAY_TIME)

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)
      isAlive = XMPPController.alive

      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive PAIR CANCEL SUCCESS response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil

      msg = SESSION_CANCEL_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'pair', device_id]
      client.send msg
      sleep(DELAY_TIME)

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)
      isAlive = XMPPController.alive

      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UNPAIR SUCCESS response' do
      device_id = Time.now.to_i
      unpair_session = rd.rd_unpair_session_insert(device_id)
      expect(unpair_session).not_to be_nil
      
      msg = UNPAIR_RESPONSE_SUCCESS % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      sleep(DELAY_TIME)
      
      unpair_session = rd.rd_unpair_session_access(device_id)
      expect(unpair_session).to be_nil
    end
    
    it 'Receive UPNP GET TIMEOUT SUCCESS response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index, device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_TIMEOUT_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'get_upnp_service', index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET TIMEOUT SUCCESS response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index, device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_TIMEOUT_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'set_upnp_service', index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP GET CANCEL SUCCESS response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index, device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_CANCEL_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'get_upnp_service', index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET CANCEL SUCCESS response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index, device_id: device_id, user_id: 2, status:'submit', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_CANCEL_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'set_upnp_service', index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET SUCCESS response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index,device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      
      msg = UPNP_ASK_RESPONSE_SUCCESS % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('updated')
      
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET SUCCESS response, nonexistent session id' do
      index = Time.now.to_i

      msg = UPNP_ASK_RESPONSE_SUCCESS % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)

      isAlive = XMPPController.alive
      expect(isAlive).to be true

      hasDeleted = rd.rd_upnp_session_delete(index)
      expect(hasDeleted).to be true
    end

    it 'Receive DDNS SETTINGS SUCCESS message' do
      index = Time.now.to_i
      session_id = index

      resend_insert = rd.rd_ddns_resend_session_insert(index)

      msg = DDNS_SETTING_SUCCESS_RESPONSE % [bot_xmpp_account, device_xmpp_account, session_id]
      client.send msg
      sleep(DELAY_TIME)

      resend_delete = rd.rd_ddns_resend_session_access(index)

      expect(resend_insert).to be true
      expect(resend_delete).to be_nil
    end
  end
  
  context 'Receive SUBMIT message' do
    
    it 'Receive PAIR COMPLETED SUCCESS response' do
      device_id = Time.now.to_i
      user_id = 2
      data = {device_id: device_id, user_id: user_id, status: 'waiting', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil

      x = nil
      i = 0
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)

      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('done')

      expect(hasDeleted).to be true

      pair_data = {user_id: user_id, device_id: device_id}
      pair = db.db_pairing_access(pair_data)
      pair_id = nil != pair ? pair.id : nil
      hasDeleted = db.db_pairing_delete(pair_id)

      expect(pair).not_to be_nil
      expect(hasDeleted).to be true

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      value = xml['x']['field'][0]['value']
      expect(title).to eq('pair')
      expect(value).to eq('completed')
    end

    it 'Receive PAIR COMPLETED SUCCESS response, but timeout, error code 899' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'waiting', start_expire_at: Time.now.to_i - 1 * 60, waiting_expire_at: Time.now.to_i - 1 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      
      x = nil
      i = 0
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)

      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('timeout')

      expect(hasDeleted).to be true

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      value = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']
      expect(title).to eq('pair')
      expect(value).to eq('completed')
      expect(error_code.to_d).to eq(899)
    end
    
    it 'Receive PAIR COMPLETED SUCCESS response, but device id incorrect, error code 898' do
      device_id = Time.now.to_i
      
      x = nil
      i = 0
      msg = PAIR_COMPLETED_REQUEST % [bot_xmpp_account, device_xmpp_account, device_id]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      value = xml['x']['field'][0]['value']
      error_code = xml['x']['field'][1]['value']
      expect(title).to eq('pair')
      expect(value).to eq('completed')
      expect(error_code.to_d).to eq(898)
    end

    it 'Receive PAIR CANCEL REQUEST from device' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 1 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      
      x = nil
      i = 0
      msg = SESSION_CANCEL_REQUEST % [bot_xmpp_account, device_xmpp_account, 'pair', device_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('cancel')
      expect(hasDeleted).to be true
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('pair')
      expect(action).to eq('cancel')
    end

    it 'Receive UPNP GET CANCEL REQUEST from device' do
      index = Time.now.to_i
      device_id = index

      data = {device_id: device_id, ip: '10.1.1.110', xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {index: index, user_id: 1, device_id: device_id, status: KSTATUS_START, service_list: '', lan_ip: ''}
      upnp = rd.rd_upnp_session_insert(data)

      expect(device).not_to be_nil
      expect(upnp).not_to be_nil

      x = nil
      i = 0
      msg = SESSION_CANCEL_REQUEST % [bot_xmpp_account, device_xmpp_account, 'get_upnp_service', index, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      upnp = rd.rd_upnp_session_access(index)
      hasDeletedUPNP = rd.rd_upnp_session_delete(index)
      hasDeletedDevice = rd.rd_device_session_delete(device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(upnp).not_to be_nil
      expect(upnp["status"]).to eq('cancel')
      expect(hasDeletedUPNP).to be true
      expect(hasDeletedDevice).to be true

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('get_upnp_service')
      expect(action).to eq('cancel')
    end

    it 'Receive UPNP SET CANCEL REQUEST from device' do
      index = Time.now.to_i
      device_id = index

      data = {device_id: device_id, ip: '10.1.1.110', xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      data = {index: index, user_id: 1, device_id: device_id, status: KSTATUS_SUBMIT, service_list: '', lan_ip: ''}
      upnp = rd.rd_upnp_session_insert(data)

      expect(device).not_to be_nil
      expect(upnp).not_to be_nil

      x = nil
      i = 0
      msg = SESSION_CANCEL_REQUEST % [bot_xmpp_account, device_xmpp_account, 'set_upnp_service', index, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      upnp = rd.rd_upnp_session_access(index)
      hasDeletedUPNP = rd.rd_upnp_session_delete(index)
      hasDeletedDevice = rd.rd_device_session_delete(device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['x']['title']
      action = xml['x']['field']['value']

      expect(upnp).not_to be_nil
      expect(upnp["status"]).to eq('cancel')
      expect(hasDeletedUPNP).to be true
      expect(hasDeletedDevice).to be true

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('set_upnp_service')
      expect(action).to eq('cancel')
    end

    it 'Receive DDNS SETTING error response, code - 998, ip not found' do
      index = Time.now.to_i
      session_id = index
      host_name = "ut%d" % index
      
      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if !xmpp.nil? then
        rd.rd_xmpp_session_delete(device_xmpp_account_node)
      end
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config_ddns')
      expect(error_code.to_d).to eq(998)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, DNS format error' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, '', domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config_ddns')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, DNS too length' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, 'ut212321321321321321321321321321321321321321312312ssdsdsdsd231323131231321', domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config_ddns')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, DNS too short' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, 'my', domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config_ddns')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 999, host name has been reserved' do
      session_id = 0
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, 'www', domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      
      expect(xml).to be_an_instance_of(Hash)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']
      expect(title).to eq('config_ddns')
      expect(error_code.to_d).to eq(999)
    end
    
    it 'Receive DDNS SETTING error response, code - 995, domain has been used' do
      index = Time.now.to_i
      host_name = "ut%d" % index
      old_device_id = index

      sleep(2)
      new_device_id = Time.now.to_i
      ip = '10.100.1.111'
      session_id = index
      
      data = {device_id: old_device_id, ip_address: ip, full_domain: host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      
      data = {device_id: new_device_id, ip: ip, xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if xmpp.nil? then
        rd.rd_xmpp_session_insert(device_xmpp_account_node, new_device_id)
      else
        rd.rd_xmpp_session_update(device_xmpp_account_node, new_device_id)
      end
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      isDeletedXMPP = TRUE
      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if !xmpp.nil? then
        isDeletedXMPP = rd.rd_xmpp_session_delete(device_xmpp_account_node)
      end

      isDeletedDDNS = db.db_ddns_delete(ddns.id)
      isDeletedDevice = rd.rd_device_session_delete(new_device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      title = xml['x']['title']
      error_code = xml['x']['field']['value']

      expect(ddns).not_to be_nil
      expect(device).not_to be_nil
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('config_ddns')
      expect(error_code.to_d).to eq(995)
      expect(isDeletedXMPP).to be true
      expect(isDeletedDDNS).to be true
      expect(isDeletedDevice).to be true
    end
    
    it 'Receive DDNS SETTING response as DDNS record has been registered' do
      index = Time.now.to_i
      device_id = index
      host_name = "ut%d" % Time.now.to_i
      ip = '10.1.1.111'
      session_id = 0
      
      data = {device_id: device_id, ip_address: ip, full_domain: host_name + '.' + domain_name}
      ddns = db.db_ddns_insert(data)
      
      data = {device_id: device_id, ip: ip, xmpp_account: jid.node}
      device = rd.rd_device_session_insert(data)

      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if xmpp.nil? then
        rd.rd_xmpp_session_insert(device_xmpp_account_node, device_id)
      else
        rd.rd_xmpp_session_update(device_xmpp_account_node, device_id)
      end
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      isDeletedXMPP = TRUE
      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if !xmpp.nil? then
        isDeletedXMPP = rd.rd_xmpp_session_delete(device_xmpp_account_node)
      end

      isDeletedDDNS = db.db_ddns_delete(ddns.id)
      isDeletedDDNSSession = rd.rd_device_session_delete(device_id)

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)
      title = xml['x']['title']
      
      expect(ddns).not_to be_nil
      expect(device).not_to be_nil
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('config_ddns')
      expect(isDeletedDDNS).to be true
      expect(isDeletedDDNSSession).to be true
    end
    
    it 'Receive DDNS SETTING SUCCESS response' do
      index = Time.now.to_i
      host_name = "ut%d" % index
      ip = '10.1.1.111'
      device_id = index
      session_id = index
      ipv4 = nil
      
      data = {device_id: device_id, ip: ip, xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if xmpp.nil? then
        rd.rd_xmpp_session_insert(device_xmpp_account_node, device_id)
      else
        rd.rd_xmpp_session_update(device_xmpp_account_node, device_id)
      end
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      xml = MultiXml.parse(x.to_s)
      title = xml['x']['title']

      ddns = db.db_ddns_access({full_domain: host_name + '.' + domain_name})
      
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
      
      ipv4_created = ipv4
      
      index = rd.rd_ddns_session_index_get
      batch_data = {index: index, device_id: device_id, full_domain: host_name + '.' + domain_name, ip: ip, action: 'delete', hasMailed: false}
      isDeleted = rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
      
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
      
      ipv4_deleted = ipv4
      resolv_i.close
      
      isDeletedXMPP = TRUE
      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if !xmpp.nil? then
        isDeletedXMPP = rd.rd_xmpp_session_delete(device_xmpp_account_node)
      end

      isDeletedDDNS = db.db_ddns_delete(ddns.id)
      isDeletedDevice = rd.rd_device_session_delete(index)

      expect(device).not_to be_nil
      expect(ddns).not_to be_nil
      expect(ddns.device_id.to_d).to eq(data[:device_id])
      expect(ddns.ip_address).to eq(data[:ip])
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('config_ddns')
      expect(ipv4_created).to be_an_instance_of(Resolv::IPv4)
      expect(isDeleted).to be true
      expect(ipv4_deleted).to be_nil
      expect(isDeletedDDNS).to be true
      expect(isDeletedDevice).to be true
    end
    
    it 'Receive DDNS SETTING SUCCESS response for update DDNS record' do
      sleep(1.1)
      index = Time.now.to_i
      device_id = index
      session_id = 0
      ipv4 = nil
      old_host_name = 'ut%d' % Time.now.to_i
      old_ip = '10.1.1.110'
      
      sleep(1.1)
      
      host_name = 'ut%d' % Time.now.to_i
      new_ip = '10.1.1.111'
      
      data = {device_id: device_id, ip_address: old_ip, full_domain: old_host_name + '.' + domain_name}
      old_ddns = db.db_ddns_insert(data)
      
      data = {device_id: device_id, ip: new_ip, xmpp_account: device_xmpp_account_node}
      device = rd.rd_device_session_insert(data)

      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if xmpp.nil? then
        rd.rd_xmpp_session_insert(device_xmpp_account_node, device_id)
      else
        rd.rd_xmpp_session_update(device_xmpp_account_node, device_id)
      end
      
      x = nil
      i = 0
      msg = DDNS_SETTING_REQUEST % [bot_xmpp_account, device_xmpp_account, host_name, domain_name, session_id, XMPP_API_VERSION]
      client.send msg
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end
      
      new_ddns = db.db_ddns_access({full_domain: host_name + '.' + domain_name})
      
      title = nil
      xml = MultiXml.parse(x.to_s)
      if !xml.nil?
        title = xml['x']['title']
      end
      
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
      
      ipv4_created = ipv4
      
      index = rd.rd_ddns_session_index_get
      batch_data = {index: index, device_id: device_id, full_domain: host_name + '.' + domain_name, ip: new_ip, action: 'delete', hasMailed: false}
      isDeleted = rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
      
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
      
      ipv4_deleted = ipv4
      resolv_i.close
      
      isDeletedXMPP = TRUE
      xmpp = rd.rd_xmpp_session_access(device_xmpp_account_node)
      if !xmpp.nil? then
        isDeletedXMPP = rd.rd_xmpp_session_delete(device_xmpp_account_node)
      end

      isDeletedDDNS = db.db_ddns_delete(new_ddns.id)
      isDeletedDevice = rd.rd_device_session_delete(device_id)

      expect(old_ddns).not_to be_nil
      expect(device).not_to be_nil
      expect(new_ddns).not_to be_nil
      expect(new_ddns.device_id.to_d).to eq(device_id)
      expect(new_ddns.ip_address).to eq(new_ip)
      expect(new_ddns.full_domain).to eq(host_name + '.' + domain_name)
      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('config_ddns')
      expect(ipv4_created).to be_an_instance_of(Resolv::IPv4)
      expect(isDeleted).to be true
      expect(ipv4_deleted).to be_nil
      expect(isDeletedDDNS).to be true
      expect(isDeletedDevice).to be true
    end
  end
  
  context 'Receive CANCEL message' do
    
    it 'Receive PAIR START FAILURE response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      
      msg = PAIR_START_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, device_id]
      client.send msg
      sleep(DELAY_TIME + 1.0)
      
      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)

      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('failure')
      expect(hasDeleted).to be true
    end

    it 'Receive PAIR COMPLETED FAILURE response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil
      
      msg = PAIR_COMPLETED_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, device_id]
      client.send msg
      sleep(DELAY_TIME)
      
      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)

      expect(pair_session).not_to be_nil
      expect(pair_session["status"]).to eq('failure')
      
      expect(hasDeleted).to be true
    end
    
    it 'Receive PAIR TIMEOUT FAILURE response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil

      msg = SESSION_TIMEOUT_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'pair', 999, device_id]
      client.send msg
      sleep(DELAY_TIME)

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)
      isAlive = XMPPController.alive

      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive PAIR CANCEL FAILURE response' do
      device_id = Time.now.to_i
      data = {device_id: device_id, user_id: 2, status: 'start', start_expire_at: Time.now.to_i + 1 * 60, waiting_expire_at: Time.now.to_i + 10 * 60}
      pair_session = rd.rd_pairing_session_insert(data)
      expect(pair_session).not_to be_nil

      msg = SESSION_CANCEL_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'pair', 999, device_id]
      client.send msg
      sleep(DELAY_TIME)

      pair_session = rd.rd_pairing_session_access(device_id)
      hasDeleted = rd.rd_pairing_session_delete(device_id)
      isAlive = XMPPController.alive

      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end
    
    it 'Receive UNPAIR FAILURE response' do
      device_id = Time.now.to_i
      unpair_session = rd.rd_unpair_session_insert(device_id)
      expect(unpair_session).not_to be_nil
      
      msg = UNPAIR_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, 999, device_id]
      client.send msg
      sleep(DELAY_TIME)
      
      unpair_session = rd.rd_unpair_session_access(device_id)
      expect(unpair_session).to be_nil
    end
    
    it 'Receive UPNP GET FAILURE response' do
      device_id = Time.now.to_i
      index = Time.now.to_i

      data = {index: index ,device_id: device_id, user_id: 2, status: 'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      
      msg = UPNP_ASK_GET_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, 999, index]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('failure')

      expect(hasDeleted).to be true
    end

    it 'Receive UPNP GET FAILURE response, nonexistent session id' do
      index = Time.now.to_i

      msg = UPNP_ASK_GET_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, 999, index]
      client.send msg
      sleep(DELAY_TIME)

      isAlive = XMPPController.alive
      expect(isAlive).to be true

      hasDeleted = rd.rd_upnp_session_delete(index)
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP GET TIMEOUT FAILURE response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index,device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_TIMEOUT_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'get_upnp_service', 999, index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP GET CANCEL FAILURE response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index,device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_CANCEL_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'get_upnp_service', 999, index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET FAILURE response' do
      device_id = Time.now.to_i
      index = Time.now.to_i

      data = {index: index, device_id: device_id, user_id: 2, status: 'start', service_list: '[{"service_name":"FTP","status":true,"enabled":true,"description":"FTP configuration", "error_code":""},{"service_name":"DDNS","status":true,"enabled":false,"description":"DDNS configuration", "error_code":""},{"service_name":"HTTP","status":true,"enabled":false,"description":"HTTP configuration", "error_code":""}]', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      
      msg = UPNP_ASK_SET_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('form')

      service_list = JSON.parse(upnp_session["service_list"])
      expect(service_list[0]['error_code']).to eq('799')
      expect(service_list[1]['error_code']).to eq('')
      expect(service_list[2]['error_code']).to eq('798')

      expect(hasDeleted).to be true
    end
    
    it 'Receive UPNP SET FAILURE response - single item' do
      device_id = Time.now.to_i
      index = Time.now.to_i

      data = {index: index, device_id: device_id, user_id: 2, status: 'start', service_list: '[{"service_name":"FTP","status":true,"enabled":true,"description":"FTP configuration", "error_code":""},{"service_name":"DDNS","status":true,"enabled":false,"description":"DDNS configuration", "error_code":""},{"service_name":"HTTP","status":true,"enabled":false,"description":"HTTP configuration", "error_code":""}]', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil

      msg = UPNP_ASK_SET_RESPONSE_FAILURE_SINGLE_ITEM % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('form')

      service_list = JSON.parse(upnp_session["service_list"])
      expect(service_list[0]['error_code']).to eq('799')
      expect(service_list[1]['error_code']).to eq('')
      expect(service_list[2]['error_code']).to eq('')

      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET FAILURE response, nonexistent session id' do
      index = Time.now.to_i

      msg = UPNP_ASK_SET_RESPONSE_FAILURE % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)

      isAlive = XMPPController.alive
      expect(isAlive).to be true

      hasDeleted = rd.rd_upnp_session_delete(index)
      expect(hasDeleted).to be true
    end
    
    it 'Receive UPNP SET TIMEOUT FAILURE response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index,device_id: device_id, user_id: 2, status:'submit', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_TIMEOUT_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'set_upnp_service', 999, index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP SET CANCEL FAILURE response' do
      device_id = Time.now.to_i
      index = Time.now.to_i
      data = {index: index,device_id: device_id, user_id: 2, status:'start', service_list: '{}', lan_ip: '10.1.1.110'}
      upnp_session = rd.rd_upnp_session_insert(data)

      msg = SESSION_CANCEL_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 'set_upnp_service', 999, index]
      client.send msg
      sleep(DELAY_TIME)

      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)
      isAlive = XMPPController.alive

      expect(upnp_session).not_to be_nil
      expect(isAlive).to be true
      expect(hasDeleted).to be true
    end

    it 'Receive DDNS FAILURE response' do
      index = Time.now.to_i
      session_id = index

      resend_insert = rd.rd_ddns_resend_session_insert(index)

      msg = DDNS_SETTING_FAILURE_RESPONSE % [bot_xmpp_account, device_xmpp_account, 999, session_id]
      client.send msg
      sleep(DELAY_TIME)

      resend_delete = rd.rd_ddns_resend_session_access(index)

      expect(resend_insert).to be true
      expect(resend_delete).to be_nil
    end
  end
  
  context 'Receive FORM message' do
    
    it 'Receive UPNP service list' do
      device_id = Time.now.to_i
      index = Time.now.to_i

      data = {index: index, device_id: device_id, user_id: 2, status: 'start', service_list: '', lan_ip: ''}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      
      msg = UPNP_ASK_RESPONSE % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME + 1.0)
      
      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('form')
      
      isValid = valid_json? upnp_session["service_list"]
      expect(isValid).to be true
      service_list = JSON.parse(upnp_session["service_list"])
      expect(service_list[0].has_key?("service_name")).to be true
      expect(service_list[0].has_key?("status")).to be true
      expect(service_list[0].has_key?("enabled")).to be true
      expect(service_list[0].has_key?("description")).to be true
      expect(service_list[0].has_key?("path")).to be true
      expect(service_list[0].has_key?("port")).to be true
      expect(service_list[0].has_key?("error_code")).to be true
      
      expect(hasDeleted).to be true
    end
    
    it 'Receive UPNP service list - single item' do
      device_id = Time.now.to_i
      index = Time.now.to_i

      data = {index: index, device_id: device_id, user_id: 2, status: 'start', service_list: '', lan_ip: ''}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
 
      msg = UPNP_ASK_RESPONSE_SINGLE_ITEM % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)
 
      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('form')

      isValid = valid_json? upnp_session["service_list"]
      expect(isValid).to be true
      service_list = JSON.parse(upnp_session["service_list"])
      expect(service_list[0].has_key?("service_name")).to be true
      expect(service_list[0].has_key?("status")).to be true
      expect(service_list[0].has_key?("enabled")).to be true
      expect(service_list[0].has_key?("description")).to be true
      expect(service_list[0].has_key?("path")).to be true
      expect(service_list[0].has_key?("port")).to be true
      expect(service_list[0].has_key?("error_code")).to be true

      expect(hasDeleted).to be true
    end
    
    it 'Receive UPNP service list - empty form' do
      device_id = Time.now.to_i
      index = Time.now.to_i

      data = {index: index, device_id: device_id, user_id: 2, status: 'start', service_list: '', lan_ip: ''}
      upnp_session = rd.rd_upnp_session_insert(data)
      expect(upnp_session).not_to be_nil
      
      msg = UPNP_ASK_EMPTY_RESPONSE % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)
      
      upnp_session = rd.rd_upnp_session_access(index)
      hasDeleted = rd.rd_upnp_session_delete(index)

      expect(upnp_session).not_to be_nil
      expect(upnp_session["status"]).to eq('form')
      
      isValid = valid_json? upnp_session["service_list"]
      expect(isValid).to be false
      
      expect(hasDeleted).to be true
    end

    it 'Receive UPNP service list, nonexistent session id' do
      index = Time.now.to_i

      msg = UPNP_ASK_EMPTY_RESPONSE % [bot_xmpp_account, device_xmpp_account, index]
      client.send msg
      sleep(DELAY_TIME)

      isAlive = XMPPController.alive
      expect(isAlive).to be true

      hasDeleted = rd.rd_upnp_session_delete(index)
      expect(hasDeleted).to be true
    end
  end
  
  context 'Other Methods' do
    it 'Batch register DDNS' do
      records = Array.new
      ipv4 = nil
      
      domain_name = 'demo.ecoworkinc.com.'
      device_id = Time.now.to_i

      rd.rd_ddns_batch_lock_set

      10.times.each do |t|
        host_name = "ut%d" % Time.now.to_i
        full_domain = "%s.%s" % [host_name, domain_name]
        ip = "10.1.1.11%d" % t

        index = rd.rd_ddns_session_index_get

        data = {index: index, device_id: device_id, host_name: host_name, domain_name: domain_name, status: KSTATUS_START}
        ddns_session = rd.rd_ddns_session_insert(data)
        expect(ddns_session).not_to be_nil

        batch_data = {index: index, device_id: device_id, full_domain: full_domain, ip: ip, action: 'update', hasMailed: false}
        rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)

        records << {index: index, full_domain: full_domain, ip: ip}
        puts '        ' + "create DNS data %s.%s" % [host_name, domain_name]
        sleep(1.1)
      end
      
      rd.rd_ddns_batch_lock_delete
      
      j = 10
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'

      records.each do |record|
        index = record[:index]
        ddns_session = rd.rd_ddns_session_access(index)
        expect(ddns_session["status"]).to eq(KSTATUS_SUCCESS)
      end

      resolv_i = Resolv::DNS.new(:nameserver => ['168.95.1.1'])
      records.each do |record|
        i = 0
        ipv4 = nil
        while ipv4.nil?
          begin
            ipv4 = resolv_i.getaddress(record[:full_domain])
          rescue Resolv::ResolvError => error
            ipv4 = nil
            puts '        ' + error.to_s
          end
          sleep(1)
          i += 1
          break if i > 120
        end

        expect(ipv4).to be_an_instance_of(Resolv::IPv4)
      end
      
      rd.rd_ddns_batch_lock_set
      
      records.each do |record|
        index = rd.rd_ddns_session_index_get
        full_domain = record[:full_domain]
        ip = record[:ip]

        batch_data = {index: index, device_id: device_id, full_domain: full_domain, ip: ip, action: 'delete', hasMailed: false}
        rd.rd_ddns_batch_session_insert(JSON.generate(batch_data), index)
      end

      rd.rd_ddns_batch_lock_delete
      
      j = 10
      while j > 0
        puts '        waiting %d second' % j
        sleep(5)
        j -= 5
      end
      puts '        waiting 0 second'

      records.each do |record|
        i = 0
        ipv4 = ''
        while !ipv4.nil?
          begin
            ipv4 = resolv_i.getaddress(record[:full_domain])
          rescue Resolv::ResolvError => error
            ipv4 = nil
            puts '        ' + error.to_s
          end
          sleep(1)
          i += 1
          break if i > 120
        end

        expect(ipv4).to be_nil
      end
      
      records.each do |record|
        index = record[:index]
        isDeletedDDNSSession = rd.rd_ddns_session_delete(index)

        expect(isDeletedDDNSSession).to be true
      end
      
      resolv_i.close
    end
  end
end
