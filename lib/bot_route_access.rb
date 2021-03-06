#!/usr/bin/env ruby

require 'aws-sdk-v1'

ROUTE_CONFIG_FILE = '../config/bot_route_config.yml'

class BotRouteAccess
  def initialize
    @Route = nil
    config_file = File.join(File.dirname(__FILE__), ROUTE_CONFIG_FILE)
    config = YAML.load(File.read(config_file))

    @reserved_hostname = config['reserved_host_name']
    @zones_list = config['zones_info']
    @Route = self.route_connection(config)
  end

  def route_connection(config)
    AWS::Route53.new
  end

  def zones_list
    @zones_list
  end

  def reserved_hostname
    @reserved_hostname
  end

  def find_zone_id(name=nil)
    return nil if name.nil?

    zone_id = nil
    @zones_list.each do |zone|
      zone_id = zone["id"] if name.downcase == zone["name"].downcase
    end
    zone_id
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
          isSuccess = nil
          puts error
        end
      rescue AWS::Route53::Errors::PriorRequestNotComplete => error
        sleep(2)
        begin
          isSuccess = rrsets.create(host_name + '.' + domain_name,
                                'A',
                                :ttl => 60,
                                :resource_records => [{:value => data[:ip]}])
        rescue Exception => error
          isSuccess = nil
          puts error
        end
      rescue Exception => error
        isSuccess = nil
        puts error
      end
    end

    return !zone_id.nil? && !isSuccess.nil? ? TRUE : FALSE
  end

  def batch_create_records(data={})
    return nil if data.empty? || !data.has_key?(:domain_name) || !data.has_key?(:records)
    domain_name = data[:domain_name].downcase
    records = data[:records]

    zone_id = self.find_zone_id(domain_name)
    isSuccess = nil
    if !zone_id.nil? then
      begin
        changes = Array.new

        records.each do |record|
          action = "UPSERT"
          action = "DELETE" if 'delete' == record[:action]
          changes << {:action => action,
                      :resource_record_set => {:name => record[:full_domain],
                                               :type => 'A',
                                               :ttl => 60,
                                               :resource_records => [{:value => record[:ip]}]}}
        end

        info = {:hosted_zone_id => zone_id,
                :change_batch => {:comment => '',
                                  :changes => changes}}
        isSuccess = @Route.client.change_resource_record_sets(info)
      rescue Exception => error
        isSuccess = nil
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
      rescue AWS::Route53::Errors::PriorRequestNotComplete => error
        sleep(2)
        begin
          isSuccess = rrset.update
        rescue Exception => error
          isSuccess = nil
          puts error
        end
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
      rescue AWS::Route53::Errors::PriorRequestNotComplete => error
        sleep(2)
        begin
          isSuccess = rrset.delete
        rescue Exception => error
          isSuccess = nil
          puts error
        end
      rescue Exception => error
        isSuccess = nil
        puts error
      end
    end
    return !zone_id.nil? && !isSuccess.nil? ? TRUE : FALSE
  end
end
