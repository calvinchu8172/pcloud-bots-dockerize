#PAIR_START_SUCCESS_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
PAIR_START_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="result">
	<title>pair</title>
	<field type='hidden' var='action'>
	  <value>start</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PAIR_START_FAILURE_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE', 'SESSION_ID']
PAIR_START_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="cancel">
	<title>pair</title>
	<field type='hidden' var='action'>
	  <value>start</value>
	</field>
	<field type='text-single' var='ERROR_CODE'>
	  <value>%d</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PAIR_COMPLETED_REQUEST % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
PAIR_COMPLETED_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
    <title>pair</title>
    <field type='hidden' var='action'>
	  <value>completed</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PAIR_TIMEOUT_REQUEST % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
PAIR_TIMEOUT_REQUEST = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="submit">
	<title>pair</title>
	<field type='hidden' var='action'>
	  <value>cancel</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="form">
	<title>upnp_service</title>
	  <item>
		<field var='service-name' type='text-single'>
		  <value>FTP</value>
		</field>
		<field var='status' type='boolean'>
		  <value>true</value>
		</field>
		<field var='enabled' type='boolean'>
		  <value>true</value>
		</field>
		<field var='description' type='text-multi'>
		  <value>FTP configuration</value>
		</field>
	  </item>
	  <item>
		<field var='service-name' type='text-single'>
		  <value>DDNS</value>
		</field>
		<field var='status' type='boolean'>
		  <value>true</value>
		</field>
		<field var='enabled' type='boolean'>
		  <value>false</value>
		</field>
		<field var='description' type='text-multi'>
		  <value>DDNS configuration</value>
		</field>
	  </item>
	  <item>
		<field var='service-name' type='text-single'>
		  <value>HTTP</value>
		</field>
		<field var='status' type='boolean'>
		  <value>true</value>
		</field>
		<field var='enabled' type='boolean'>
		  <value>false</value>
		</field>
		<field var='description' type='text-multi'>
		  <value>HTTP configuration</value>
		</field>
	  </item>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE_SUCCESS % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_RESPONSE_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
	<title>upnp_service</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE_FAILURE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE', 'SESSION_ID']
UPNP_ASK_RESPONSE_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
	<title>upnp_service</title>
	<field type='text-single' var='ERROR_CODE'>
	  <value>%d</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT

#UNPAIR_RESPONSE_SUCCESS % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UNPAIR_RESPONSE_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
	<title>unpair</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#UNPAIR_RESPONSE_FAILURE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE', 'SESSION_ID']
UNPAIR_RESPONSE_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
	<title>unpair</title>
	<field type='text-single' var='ERROR_CODE'>
	  <value>%d</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT