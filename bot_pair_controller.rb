#!/usr/bin/env ruby

require './bot_db_access'
require 'blather/client/dsl'

BOT_SENDER_XMPP_ACCOUNT = 'job2@10.1.1.110/sender'
BOT_LISTENER_XMPP_ACCOUNT = 'job2@10.1.1.110/listener'
BOT_XMPP_PASSWORD = '12345'

module PairSenderController
  extend Blather::DSL
  
  def self.new
    setup BOT_SENDER_XMPP_ACCOUNT, BOT_XMPP_PASSWORD
    puts 'Init sender account '
    
    return client
  end
  
  def self.run
    EM.run { client.run }
  end
  
  def self.send_request(to, session_id)
    puts 'Send resbonse to ' + to + client.jid.to_s
write_to_stream <<EOT
<message to="#{to}" type="normal" from="#{BOT_SENDER_XMPP_ACCOUNT}" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>start</value>
    </field>
  </x>
  <thread>#{session_id}</thread>
</message>
EOT
  end
  
end

module PairListenController
  extend Blather::DSL
  
  def self.new
    setup BOT_LISTENER_XMPP_ACCOUNT, BOT_XMPP_PASSWORD
    puts 'Init listen account '
  end
  
  def self.run
    EM.run { client.run }
  end
  
  subscription :request? do |s|
    write_to_stream s.approve!
  end
  
  message do |msg|
    puts msg.body + client.jid.to_s
    write_to_stream msg.reply
  end
end