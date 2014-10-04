#!/usr/bin/env ruby

require 'json'

def valid_json? json_
  begin
    JSON.parse(json_)
    return true
  rescue
    return false
  end
end

def find_hostname(full_domain=nil)
  return nil if nil == full_domain
  
  units = full_domain.split('.')
  host_name = units[0]
  
  return host_name
end

def find_domainname(full_domain=nil)
  return nil if nil == full_domain
  
  units = full_domain.split('.')
  units.shift
  domain_name = units.join('.')
  domain_name += '.' if '.' != domain_name[-1, 1]
  
  return domain_name
end