# HEALTH_CHECK_SEND_RESPONSE % ['BOT_ID', 'BOT_HEALTH_CHECK_ID', 'THREAD_ID']
HEALTH_CHECK_SEND_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="form">
    <title>bot_health_check_send</title>
    <item>
      <field type="text-single" var="health_check_send_time">
        <value>%d</value>
      </field>
      <field type="text-single" var="bot_receive_time">
        <value>%d</value>
      </field>
      <field type="text-single" var="bot_send_time">
        <value>%d</value>
      </field>
      <field type="text-single" var="health_check_receive_time">
        <value>%d</value>
      </field>
    </item>
  </x>
  <thread>%d</thread>
</message>
EOT

# HEALTH_CHECK_SUCCESS_RESPONSE % ['BOT_HEALTH_CHECK_ID', 'BOT_ID', 'THREAD_ID']
HEALTH_CHECK_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>bot_health_check_success</title>
    <item>
      <field type="text-single" var="health_check_send_time">
        <value>%d</value>
      </field>
      <field type="text-single" var="bot_receive_time">
        <value>%d</value>
      </field>
      <field type="text-single" var="bot_send_time">
        <value>%d</value>
      </field>
      <field type="text-single" var="health_check_receive_time">
        <value>%d</value>
      </field>
    </item>
  </x>
  <thread>%d</thread>
</message>
EOT
