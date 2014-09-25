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