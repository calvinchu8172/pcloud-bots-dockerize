require_relative 'lib/bot_xmpp_db_access'
require_relative 'lib/bot_redis_access'

require 'rubygems'
require 'active_record'
require 'blather/client'
require './lib/bot_pair_protocol_template'
require './lib/bot_xmpp_spec_protocol_template'
require 'pry'

XMPP_ACCOUNT = 'd0023f8311041-tempserialnum0000@localhost/device'
XMPP_PASSWORD = '8kP0wNjEkA'
USER_EMAIL = 'spjay1@gmail.com'

username = 'd0023f8311041-tempserialnum0000'
xmpp_db = BotXmppDBAccess.new
XMPP_PASSWORD = XMPP_User.find_by(username: username).password


puts '%s start connect to XMPP server' % XMPP_ACCOUNT

setup XMPP_ACCOUNT , XMPP_PASSWORD

puts 'Waiting XMPP connection ready ...'

when_ready { puts "Connected !" }

session_id = Time.now.to_i
to = 'bot1@localhost/device'
from = XMPP_ACCOUNT
msg = DEVICE_INFO_RESPONSE_SUCCESS % [to, from, session_id]
write_to_stream msg

binding.pry





# DEVICE_INFO_RESPONSE_SUCCESS = <<EOT
# <message to="%s" type="normal" from="%s" lang="en">
#     <x
#         xmlns="jabber:x:data" type="result">
#         <title>bot_get_device_information</title>
#         <field var="cpu-temperature-celsius" type="text-single">
#             <value>41.00 </value>
#         </field>
#         <field var="cpu-temperature-fahrenheit" type="text-single">
#             <value> 54.78</value>
#         </field>
#         <field var="cpu-temperature-warning" type="boolean">
#             <value>false</value>
#         </field>
#         <field var="fan-speed" type="text-single">
#             <value>740 PRM</value>
#         </field>
#         <field var="raid-status" type="text-single">
#             <value>Healthy</value>
#         </field>
#   <item>
#     <field var="volume-name" type="text-single">
#       <value>Volume2</value>
#     </field>
#        <field var="used-capacity" type="text-single">
#          <value>400</value>
#        </field>
#        <field var="total-capacity" type="text-single">
#          <value>1832.96</value>
#        </field>
#     <field var="warning" type="boolean">
#       <value>false</value>
#     </field>
#   </item>
#     </x>
#     <thread>%d</thread>
# </message>
# EOT
