require_relative '../lib/bot_route_access'
require 'aws-sdk'
require 'resolv'

describe BotRouteAccess do
  config_file = File.join(File.dirname(__FILE__), ROUTE_CONFIG_FILE)
  config = YAML.load(File.read(config_file))
  
  it 'Config file check' do
    expect(config).to be_an_instance_of(Hash)
    
    expect(config).to have_key('access_key_id')
    expect(config).to have_key('secret_access_key')
    
    expect(config['access_key_id']).not_to eq('xxx')
    expect(config['secret_access_key']).not_to eq('xxx')
  end
  
  let(:route) {BotRouteAccess.new}
  let(:resolv_i){Resolv::DNS.new(:nameserver => ['168.95.1.1'])}
  
  dns_data = {host_name: 'mytest3', domain_name: 'demo.ecoworkinc.com.', ip: '10.1.1.112'}
  ipv4 = nil
  
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
    
    dns_data[:domain_name] = 'demo.ecoworkinc.com'
    isSuccess = route.create_record(dns_data)
    expect(isSuccess).to be false
    
    dns_data[:domain_name] = 'demo.ecoworkinc.com.'
  end
  
  it "Update DNS record #{dns_data[:host_name]}.#{dns_data[:domain_name]} - #{dns_data[:ip]}" do
    dns_data[:ip] = '10.1.1.115'
    isSuccess = route.update_record(dns_data)
    expect(isSuccess).to be true
    
    dns_data[:domain_name] = 'demo.ecoworkinc.com'
    isSuccess = route.update_record(dns_data)
    expect(isSuccess).to be false
    
    dns_data[:domain_name] = 'demo.ecoworkinc.com.'
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
    
    dns_data[:domain_name] = 'demo.ecoworkinc.com'
    isSuccess = route.delete_record(dns_data)
    expect(isSuccess).to be false
  end
  
  it 'Close DNS resolv' do
    resolv_i.close  
  end
end