#!/usr/bin/env ruby

# SESSION_CANCEL_REQUEST % ['RESPONSE_ID', 'REQUEST_ID', 'MESSAGE_TITLE', 'SESSION_ID', 'VERSION']
SESSION_CANCEL_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="submit">
      <title>%s</title>
      <field type='hidden' var='action'>
         <value>cancel</value>
      </field>
   </x>
   <thread>%d</thread>
   <api_version>%s</api_version>
</message>
EOT

# SESSION_CANCEL_SUCCESS_RESPONSE % ['RESPONSE_ID', 'REQUEST_ID', 'MESSAGE_TITLE', 'SESSION_ID']
SESSION_CANCEL_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="result">
      <title>%s</title>
      <field type='hidden' var='action'>
         <value>cancel</value>
      </field>
   </x>
   <thread>%d</thread>
</message>
EOT

# SESSION_CANCEL_FAILURE_RESPONSE % ['RESPONSE_ID', 'REQUEST_ID', 'MESSAGE_TITLE', 'ERROR_CODE', 'SESSION_ID']
SESSION_CANCEL_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="cancel">
      <title>%s</title>
      <field type='hidden' var='action'>
         <value>cancel</value>
      </field>
      <field type='text-single' var='ERROR_CODE'>
         <value>%d</value>
      </field>
   </x>
   <thread>%d</thread>
</message>
EOT

# SESSION_TIMEOUT_REQUEST % ['RESPONSE_ID', 'REQUEST_ID', 'MESSAGE_TITLE', 'SESSION_ID', 'VERSION']
SESSION_TIMEOUT_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="submit">
      <title>%s</title>
      <field type='hidden' var='action'>
         <value>timeout</value>
      </field>
   </x>
   <thread>%d</thread>
   <api_version>%s</api_version>
</message>
EOT

# SESSION_TIMEOUT_SUCCESS_RESPONSE % ['RESPONSE_ID', 'REQUEST_ID', 'MESSAGE_TITLE', 'SESSION_ID']
SESSION_TIMEOUT_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>%s</title>
    <field type='hidden' var='action'>
      <value>timeout</value>
      </field>
    </x>
    <thread>%d</thread>
</message>
EOT

# SESSION_TIMEOUT_FAILURE_RESPONSE % ['RESPONSE_ID', 'REQUEST_ID', 'MESSAGE_TITLE', 'ERROR_CODE', 'SESSION_ID']
SESSION_TIMEOUT_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>%s</title>
    <field type='hidden' var='action'>
      <value>timeout</value>
    </field>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

# PAIR_START_REQUEST % ['DEVICE_ID', 'BOT_ID', 'EXPIRE_TIME', 'SESSION_ID', 'VERSION']
PAIR_START_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>start</value>
    </field>
    <field type='hidden' var='timeout'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
  <api_version>%s</api_version>
</message>
EOT

# PAIR_COMPLETED_SUCCESS_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'CLOUD_ID', 'SESSION_ID']
PAIR_COMPLETED_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>completed</value>
    </field>
    <field type='hidden' var='cloud_id'>
      <value>%s</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PAIR_COMPLETED_FAILURE_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE', 'SESSION_ID']
PAIR_COMPLETED_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>completed</value>
    </field>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#UNPAIR_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID', 'VERSION']
UNPAIR_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>unpair</title>
  </x>
  <thread>%d</thread>
  <api_version>%s</api_version>
</message>
EOT

#UPNP_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'LANGUAGE', 'EXPIRE_TIME', 'SESSION_ID', 'VERSION']
UPNP_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="%s">
  <x xmlns="jabber:x:data" type="submit">
    <title>get_upnp_service</title>
    <field type='hidden' var='timeout'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
  <api_version>%s</api_version>
</message>
EOT

#UPNP_FIELD_ITEM % ['SERVICE_NAME', 'STATUS', 'ENABLED', 'DESCRIPTION', 'PATH', 'LAN_PORT', 'WAN_PORT']
UPNP_FIELD_ITEM = <<EOT
<item>
  <field var='service-name' type='text-single'>
    <value>%s</value>
  </field>
  <field var='status' type='boolean'>
    <value>%s</value>
  </field>
  <field var='enabled' type='boolean'>
    <value>%s</value>
  </field>
  <field var='description' type='text-multi'>
    <value>%s</value>
  </field>
  <field var='path' type='text-single'>
    <value>%s</value>
  </field>
  <field var='lan-port' type='text-single'>
    <value>%d</value>
  </field>
  <field var='wan-port' type='text-single'>
    <value>%d</value>
  </field>
</item>
EOT

#UPNP_SETTING_REQUEST % ['DEVICE_ID', 'BOT_ID', 'LANGUAGE', 'FIELD_ITEM', 'EXPIRE_TIME', 'SESSION_ID']
UPNP_SETTING_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="%s">
  <x xmlns="jabber:x:data" type="submit">
    <title>set_upnp_service</title>
    %s
    <field type='hidden' var='timeout'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#DDNS_SETTING_REQUEST % ['RESPONSE_ID', 'REQUEST_ID', 'HOSTNAME', 'DOMAINNAME','SESSION_ID', 'VERSION']
DDNS_SETTING_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>config_ddns</title>
    <field type='text-single' var='hostname_prefix'>
      <value>%s</value>
    </field>
    <field type='text-single' var='hostname_suffix'>
      <value>%s</value>
    </field>
  </x>
  <thread>%d</thread>
  <api_version>%s</api_version>
</message>
EOT

#DDNS_SETTING_SUCCESS_RESPONSE % ['REQUEST_ID', 'RESPONSE_ID', 'SESSION_ID']
DDNS_SETTING_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>config_ddns</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#DDNS_SETTING_FAILURE_RESPONSE % ['REQUEST_ID', 'RESPONSE_ID', 'ERROR_CODE', 'SESSION_ID']
DDNS_SETTING_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>config_ddns</title>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PERMISSION_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'SHARE_POINT', 'PERMISSION', 'CLOUD_ID', 'EXPIRE_TIME', 'SESSION_ID', 'VERSION']
PERMISSION_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="submit">
      <title>bot_set_share_permission</title>
      <field type='text-single' var='sharename'>
        <value>%s</value>
      </field>
      <field type='text-single' var='user_new_permission'>
        <value>%s</value>
      </field>
      <field type='text-single' var='user_cloud_id'>
        <value>%s</value>
      </field>
      <field type='hidden' var='timeout'>
        <value>%d</value>
      </field>
   </x>
   <thread>%s</thread>
   <api_version>%s</api_version>
</message>
EOT

#DEVICE_INFO_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'EXPIRE_TIME', 'SESSION_ID', 'VERSION']
DEVICE_INFO_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
    <x xmlns="jabber:x:data" type="submit">
        <title>bot_get_device_information</title>
        <field type="hidden" var="timeout">
          <value>%d</value>
        </field>
    </x>
    <thread>%d</thread>
    <api_version>%s</api_version>
</message>
EOT

# LED_INDICATOR_REQUEST % ['DEVICE_ID', 'BOT_ID', 'BLINK_TIME', 'SESSION_ID', 'VERSION']
LED_INDICATOR_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>bot_led_indicator</title>
    <field var="blink-second" type="text-single">
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
  <api_version>%s</api_version>
</message>
EOT

#PACKAGE_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'EXPIRE_TIME', 'SESSION_ID', 'VERSION']
PACKAGE_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
     <title>bot_get_package_list</title>
  <field var="timeout" type="text-single">
    <value>%s</value>
  </field>
    </x>
    <thread>%s</thread>
    <api_version>%s</api_version>
</message>
EOT


#PACKAGE_FIELD_ITEM % ['PACKAGE_NAME', 'new-status']
PACKAGE_FIELD_ITEM = <<EOT
<item>
       <field var="package-name" type="text-single">
         <value>%s</value>
       </field>
       <field var="new-status" type="boolean">
         <value>%s</value>
       </field>
</item>
EOT

#PACKAGE_SETTING_REQUEST % ['DEVICE_ID', 'BOT_ID','EXPIRE_TIME', 'FIELD_ITEM',  'SESSION_ID']
PACKAGE_SETTING_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
   <x xmlns="jabber:x:data" type="submit">
     <title>bot_set_package_list</title>
     <field type='hidden' var='timeout'>
        <value>%d</value>
     </field>
    %s
  </x>
  <thread>%s</thread>
  <api_version>v1.0</api_version>
</message>
EOT



# ALIVE_TESTER % ['BOT_ID']
ALIVE_TESTER = <<EOT
<iq from='%s' to='capulet.lit' id='c2s1' type='get'>
  <ping xmlns='urn:xmpp:ping'/>
</iq>
EOT