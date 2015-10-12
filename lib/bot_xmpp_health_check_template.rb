# HEALTH_CHECK_SEND_RESPONSE % ['BOT_ID', 'BOT_HEALTH_CHECK_ID', 'SESSION_ID']
HEALTH_CHECK_SEND_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>bot_health_check_send</title>
  </x>
  <thread>%d</thread>
</message>
EOT

# HEALTH_CHECK_SUCCESS_RESPONSE % ['BOT_HEALTH_CHECK_ID', 'BOT_ID', 'SESSION_ID']
HEALTH_CHECK_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>bot_health_check_success</title>
  </x>
  <thread>%d</thread>
</message>
EOT
