# LED_INDICATOR_REQUEST_SUCCESS_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'SESSION_ID']
HEALTH_CHECK_SEND_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>bot_health_check_send</title>
  </x>
  <thread>%d</thread>
</message>
EOT

HEALTH_CHECK_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>bot_health_check_success</title>
  </x>
  <thread>%d</thread>
</message>
EOT

# LED_INDICATOR_REQUEST_FAILURE_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'ERROR_CODE', 'SESSION_ID']
HEALTH_CHECK_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>bot_health_check</title>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT