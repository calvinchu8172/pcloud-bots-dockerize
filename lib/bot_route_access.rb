#!/usr/bin/env ruby

require 'aws-sdk'

ROUTE_CONFIG_FILE = '../config/bot_route_config.yml'

class BotRouteAccess
  def initialize
    @Route = nil
    @zones_list = Array.new
    config_file = File.join(File.dirname(__FILE__), ROUTE_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    
    @Route = self.route_connection(config)
    self.find_zone_id('')
  end
  
  def route_connection(config)
    account = {:access_key_id => config['access_key_id'],
               :secret_access_key => config['secret_access_key']
              }
    
    return AWS::Route53.new(account)
  end
  
  def zones_list
    @zones_list
  end
  
  def find_zone_id(name=nil)
    return nil if name.nil?
    
    zone_id = nil
    @zones_list.each do |zone|
      zone_id = zone[:id] if name.downcase == zone[:name].downcase
    end
    
    if zone_id.nil? then
      list = Array.new
      zones = @Route.client.list_hosted_zones
      zones[:hosted_zones].each do |zone|
        list << {id: zone[:id], name: zone[:name].downcase}
        zone_id = zone[:id] if name.downcase == zone[:name].downcase
      end
      @zones_list = list
    end
    
    return zone_id
  end
  
  def create_record(data={})
    return nil if data.empty? || !data.has_key?(:host_name) || !data.has_key?(:domain_name) || !data.has_key?(:ip)
    
    domain_name = data[:domain_name].downcase
    host_name = data[:host_name].downcase
    
    zone_id = self.find_zone_id(domain_name)
    isSuccess = nil
    if !zone_id.nil? then
      rrsets = @Route.hosted_zones[zone_id].rrsets
      begin
        isSuccess = rrsets.create(host_name + '.' + domain_name,
                                'A',
                                :ttl => 60,
                                :resource_records => [{:value => data[:ip]}])
      rescue AWS::Route53::Errors::InvalidChangeBatch => error
        begin
          rrset = rrsets[host_name + '.' + domain_name, 'A']
          ip = rrset.resource_records[0][:value]
          if ip != data[:ip] then
            rrset.resource_records = [{:value => data[:ip]}]
            rrset.update
          end
          isSuccess = TRUE
        rescue Exception => error
          isSuccess = FALSE
          puts error
        end
      rescue Exception => error
        puts error
      end
    end
    
    return !zone_id.nil? && !isSuccess.nil? ? TRUE : FALSE
  end
  
  def update_record(data={})
    return nil if data.empty? || !data.has_key?(:host_name) || !data.has_key?(:domain_name) || !data.has_key?(:ip)
    
    domain_name = data[:domain_name].downcase
    host_name = data[:host_name].downcase
    
    zone_id = self.find_zone_id(domain_name)
    isSuccess = nil
    if !zone_id.nil? then
      rrsets = @Route.hosted_zones[zone_id].rrsets
      rrset = rrsets[host_name + '.' + domain_name, 'A']
      rrset.resource_records = [{:value => data[:ip]}]
      
      begin
        isSuccess = rrset.update
      rescue Exception => error
        isSuccess = nil
        puts error
      end
    end
    
    return !zone_id.nil? && !isSuccess.nil? ? TRUE : FALSE
  end
  
  def delete_record(data={}) 
    return nil if data.empty? || !data.has_key?(:host_name) || !data.has_key?(:domain_name)
    
    domain_name = data[:domain_name].downcase
    host_name = data[:host_name].downcase
    
    zone_id = self.find_zone_id(domain_name)
    isSuccess = nil
    if !zone_id.nil? then
      rrsets = @Route.hosted_zones[zone_id].rrsets
      rrset = rrsets[host_name + '.' + domain_name, 'A']
      
      begin
        isSuccess = rrset.delete
      rescue AWS::Core::Resource::NotFound => error
        isSuccess = TRUE
        puts error
      rescue Exception => error
        isSuccess = nil
        puts error
      end
    end
    return !zone_id.nil? && !isSuccess.nil? ? TRUE : FALSE
  end
end