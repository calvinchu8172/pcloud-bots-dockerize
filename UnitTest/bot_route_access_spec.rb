require_relative '../lib/bot_route_access'
require 'aws-sdk-v1'
require 'resolv'

describe BotRouteAccess do
  config_file = File.join(File.dirname(__FILE__), ROUTE_CONFIG_FILE)
  config = YAML.load(File.read(config_file))
  
  it 'Config file check' do
    expect(config).to be_an_instance_of(Hash)
    
    expect(config).to have_key('access_key_id')
    expect(config).to have_key('secret_access_key')
    expect(config).to have_key('reserved_host_name')
    expect(config).to have_key('zones_info')
    
    expect(config['access_key_id']).not_to eq('xxx')
    expect(config['secret_access_key']).not_to eq('xxx')
    expect(config['reserved_host_name'].length).not_to eq(0)
    expect(config['zones_info'].length).not_to eq(0)
  end
  
  let(:route) {BotRouteAccess.new}
  let(:resolv_i){Resolv::DNS.new(:nameserver => ['168.95.1.1'])}
  
  dns_data = {host_name: 'mytest3', domain_name: 'pcloud.ecoworkinc.com.', ip: '10.1.1.112'}
  ipv4 = nil
  
  it "Return reserved host name list" do
    reserved = route.reserved_hostname
    expect(reserved.length).not_to eq(0)
  end
  
  it "Return zones list" do
    zones_list = route.zones_list
    expect(zones_list.length).not_to eq(0)
  end
  
  it "Create DNS record #{dns_data[:host_name]}.#{dns_data[:domain_name]} - #{dns_data[:ip]}" do
    isSuccess = route.create_record(dns_data)
    expect(isSuccess).to be true
    
    i = 0
    while ipv4.nil?
      begin
        ipv4 = resolv_i.getaddress(dns_data[:host_name] + '.' + dns_data[:domain_name])
      rescue Resolv::ResolvError => error
        ipv4 = nil
        puts '        ' + error.to_s
      end
      sleep(1)
      i += 1
      break if i > 120
    end
      
    expect(ipv4).to be_an_instance_of(Resolv::IPv4)
    
    dns_data[:domain_name] = 'pcloud.ecoworkinc.com'
    isSuccess = route.create_record(dns_data)
    expect(isSuccess).to be false
    
    dns_data[:domain_name] = 'pcloud.ecoworkinc.com.'

    sleep 1

    isDelete = route.delete_record(dns_data)
    expect(isDelete).to be true
  end
  
  it 'Create DNS record in batch mode' do
    records = Array.new
    domain = 'pcloud.ecoworkinc.com.'

    10.times.each do |t|
      host_name = "test%d" % Time.now.to_i
      records << {full_domain: "%s.%s" % [host_name, domain], ip: '10.1.1.11%d' % t, action: 'update'}
      puts '        ' + "create DNS data %s.%s" % [host_name, domain]
      sleep(1.1)
    end

    isSuccess = route.batch_create_records({domain_name: domain, records: records})
    expect(isSuccess).to be true

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

    10.times.each do |t|
      records[t][:action] = 'delete'
    end

    hasDeleted = route.batch_create_records({domain_name: domain, records: records})
    expect(hasDeleted).to be true

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
  end

  it "Update DNS record #{dns_data[:host_name]}.#{dns_data[:domain_name]} - #{dns_data[:ip]}" do
    isCreate = route.create_record(dns_data)
    expect(isCreate).to be true

    dns_data[:ip] = '10.1.1.115'
    isSuccess = route.update_record(dns_data)
    expect(isSuccess).to be true
    
    dns_data[:domain_name] = 'pcloud.ecoworkinc.com'
    isSuccess = route.update_record(dns_data)
    expect(isSuccess).to be false
    
    dns_data[:domain_name] = 'pcloud.ecoworkinc.com.'

    isDelete = route.delete_record(dns_data)
    expect(isDelete).to be true
  end
  
  it "Delete DNS record #{dns_data[:host_name]}.#{dns_data[:domain_name]} - #{dns_data[:ip]}" do
    isSuccess = route.delete_record(dns_data)
    expect(isSuccess).to be true
    
    i = 0
    while !ipv4.nil?
      begin
        ipv4 = resolv_i.getaddress(dns_data[:host_name] + '.' + dns_data[:domain_name])
      rescue Resolv::ResolvError => error
        ipv4 = nil
        puts '        ' + error.to_s
      end
      sleep(1)
      i += 1
      break if i > 120
    end
      
    expect(ipv4).to be_nil
    
    dns_data[:domain_name] = 'pcloud.ecoworkinc.com'
    isSuccess = route.delete_record(dns_data)
    expect(isSuccess).to be false
  end
  
  it 'Close DNS resolv' do
    resolv_i.close  
  end
end
