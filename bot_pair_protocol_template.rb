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
