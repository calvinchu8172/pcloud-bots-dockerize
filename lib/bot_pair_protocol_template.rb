#!/usr/bin/env ruby

# PAIR_START_REQUEST % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
PAIR_START_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>start</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

# PAIR_COMPLETED_SUCCESS_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'EMAIL', 'SESSION_ID']
PAIR_COMPLETED_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>completed</value>
    </field>
    <field type='hidden' var='email'>
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

#PAIR_TIMEOUT_SUCCESS_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
PAIR_TIMEOUT_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>pair</title>
    <field type='hidden' var='action'>
      <value>cancel</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PAIR_TIMEOUT_FAILURE_FAILURE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE','SESSION_ID']
PAIR_TIMEOUT_FAILURE_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>pair</title>
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

#UNPAIR_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UNPAIR_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>unpair</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_REQUEST % ['DEVICE_ID', 'BOT_ID', 'LANGUAGE','SESSION_ID']
UPNP_ASK_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="%s">
  <x xmlns="jabber:x:data" type="submit">
    <title>get_upnp_service</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_FIELD_ITEM % ['SERVICE_NAME', 'STATUS', 'ENABLED', 'DESCRIPTION']
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
</item>
EOT

#UPNP_SETTING_REQUEST % ['DEVICE_ID', 'BOT_ID', 'LANGUAGE', 'FIELD_ITEM', 'SESSION_ID']
UPNP_SETTING_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="%s">
  <x xmlns="jabber:x:data" type="submit">
    <title>set_upnp_service</title>
    %s
  </x>
  <thread>%d</thread>
</message>
EOT

#DDNS_SETTING_REQUEST % ['RESPONSE_ID', 'REQUEST_ID', 'HOSTNAME', 'DOMAINNAME','SESSION_ID']
DDNS_SETTING_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>config</title>
    <field type='text-single' var='hostname_prefix'>
      <value>%s</value>
    </field>
    <field type='text-single' var='hostname_suffix'>
      <value>%s</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#DDNS_SETTING_SUCCESS_RESPONSE % ['REQUEST_ID', 'RESPONSE_ID', 'SESSION_ID']
DDNS_SETTING_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>config</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#DDNS_SETTING_FAILURE_RESPONSE % ['REQUEST_ID', 'RESPONSE_ID', 'ERROR_CODE', 'SESSION_ID']
DDNS_SETTING_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>config</title>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT