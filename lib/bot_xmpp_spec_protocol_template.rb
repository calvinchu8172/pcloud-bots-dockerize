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

#PAIR_TIMEOUT_FAILURE_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE', 'SESSION_ID']
PAIR_TIMEOUT_FAILURE_RESPONSE = <<EOT
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

#UPNP_ASK_RESPONSE_SINGLE_ITEM % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_RESPONSE_SINGLE_ITEM = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="form">
	<title>get_upnp_service</title>
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
  		<field var='port' type='text-single'>
        <value>21</value>
      </field>
      <field var='path' type='text-single'>
        <value>ftp://wanip:port</value>
      </field>
	  </item>
    <item>
      <field var='used-wan-port' type='text-single'>
          <value>8000</value>
      </field>
    </item>
    <item>
      <field var='used-wan-port' type='text-single'>
          <value>9000</value>
      </field>
    </item>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="form">
	<title>get_upnp_service</title>
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
		<field var='port' type='text-single'>
      <value>21</value>
    </field>
    <field var='path' type='text-single'>
      <value>ftp://wanip:port</value>
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
		<field var='port' type='text-single'>
      <value>53</value>
    </field>
    <field var='path' type='text-single'>
      <value></value>
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
	  <field var='port' type='text-single'>
      <value>80</value>
    </field>
    <field var='path' type='text-single'>
      <value>http://wanip:port</value>
    </field>
  </item>
  <item>
    <field var='used-wan-port' type='text-single'>
        <value>8000</value>
    </field>
  </item>
  <item>
    <field var='used-wan-port' type='text-single'>
        <value>9000</value>
    </field>
  </item>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_EMPTY_RESPONSE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_EMPTY_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
  <x xmlns="jabber:x:data" type="form">
	<title>get_upnp_service</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE_SUCCESS % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_RESPONSE_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
	<title>set_upnp_service</title>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE_FAILURE % ['DEVICE_ID', 'BOT_ID', 'ERROR_CODE', 'SESSION_ID']
UPNP_ASK_GET_RESPONSE_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
	<title>get_upnp_service</title>
	<field type='text-single' var='ERROR_CODE'>
	  <value>%d</value>
	</field>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE_FAILURE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_SET_RESPONSE_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
	<title>set_upnp_service</title>
	<item>
	  <field type='textsingle' var='ERROR_CODE'>
	    <value>799</value>
	  </field>
	  <field var='servicename' type='textsingle'>
		<value>FTP</value>
	  </field>
	</item>
	<item>
	  <field type='textsingle' var='ERROR_CODE'>
	    <value>798</value>
	  </field>
	  <field var='servicename' type='textsingle'>
		<value>HTTP</value>
	  </field>
	</item>
  </x>
  <thread>%d</thread>
</message>
EOT

#UPNP_ASK_RESPONSE_FAILURE % ['DEVICE_ID', 'BOT_ID', 'SESSION_ID']
UPNP_ASK_SET_RESPONSE_FAILURE_SINGLE_ITEM = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
	<title>set_upnp_service</title>
	<item>
	  <field type='textsingle' var='ERROR_CODE'>
	    <value>799</value>
	  </field>
	  <field var='servicename' type='textsingle'>
		<value>FTP</value>
	  </field>
	</item>
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

#PERMISSION_SETTING_SUCCESS_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'SESSION_ID']
PERMISSION_SETTING_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="result">
    <title>bot_set_share_permission</title>
    <field type='hidden' var='status'>
       <value>success</value>
    </field>
   </x>
   <thread>%d</thread>
</message>
EOT

#PERMISSION_SETTING_FAILURE_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'ERROR_CODE', 'SESSION_ID']
PERMISSION_SETTING_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
   <x xmlns="jabber:x:data" type="cancel">
    <title>bot_set_share_permission</title>
    <field type="text-single" var="ERROR_CODE">
        <value>%s</value>
    </field>
   </x>
   <thread>%d</thread>
</message>
EOT

#DEVICE_INFO_RESPONSE_SUCCESS % ['BOT_ID', 'DEVICE_ID', 'SESSION_ID']
DEVICE_INFO_RESPONSE_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
    <x
        xmlns="jabber:x:data" type="result">
        <title>bot_get_device_information</title>
        <field var="cpu-temperature-celsius" type="text-single">
            <value>41.00 </value>
        </field>
        <field var="cpu-temperature-fahrenheit" type="text-single">
            <value> 54.78</value>
        </field>
        <field var="cpu-temperature-warning" type="boolean">
            <value>false</value>
        </field>
        <field var="fan-speed" type="text-single">
            <value>740 PRM</value>
        </field>
        <field var="raid-status" type="text-single">
            <value>Healthy</value>
        </field>
  <item>
    <field var="volume-name" type="text-single">
      <value>Volume2</value>
    </field>
       <field var="used-capacity" type="text-single">
         <value>400</value>
       </field>
       <field var="total-capacity" type="text-single">
         <value>1832.96</value>
       </field>
    <field var="warning" type="boolean">
      <value>false</value>
    </field>
  </item>
    </x>
    <thread>%d</thread>
</message>
EOT

#DEVICE_INFO_RESPONSE_FAILURE % ['BOT_ID', 'DEVICE_ID', 'ERROR_CODE', 'SESSION_ID']
DEVICE_INFO_RESPONSE_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>bot_get_device_information</title>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

# LED_INDICATOR_REQUEST_SUCCESS_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'SESSION_ID']
LED_INDICATOR_REQUEST_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
    <title>bot_led_indicator</title>
  </x>
  <thread>%d</thread>
</message>
EOT

# LED_INDICATOR_REQUEST_FAILURE_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'ERROR_CODE', 'SESSION_ID']
LED_INDICATOR_REQUEST_FAILURE_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
    <title>bot_led_indicator</title>
    <field type='text-single' var='ERROR_CODE'>
      <value>%d</value>
    </field>
  </x>
  <thread>%d</thread>
</message>
EOT

#PACKAGE_ASK_REQUEST_FAILURE % [ 'BOT_ID', 'DEVICE_ID', 'SESSION_ID']
PACKAGE_ASK_REQUEST_FAILURE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
    <x xmlns="jabber:x:data" type="cancel">
     <title>bot_get_package_list</title>
     <field var="ERROR_CODE" type="text-single">
       <value>489</value>
     </field>
    </x>
    <thread>%s</thread>
</message>
EOT

#PACKAGE_ASK_REQUEST_SUCCESS % [ 'BOT_ID', 'DEVICE_ID', 'SESSION_ID']
PACKAGE_ASK_REQUEST_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
    <x xmlns="jabber:x:data" type="result">
        <title>bot_get_package_list</title>
        <item>
            <field type="text-single" var="package-name">
                <value>NZBGet</value>
            </field>
            <field type="text-single" var="status">
                <value>false</value>
            </field>
            <field type="text-multi" var="requires">
                <value></value>
            </field>
            <field type="text-single" var="version">
                <value>14.1zypkg003</value>
            </field>
            <field type="text-multi" var="description">
                <value>This package downloads .nzb file from Usenet. Default username:nzbget password:1234</value>
            </field>
        </item>
       
        <item>
            <field type="text-single" var="package-name">
                <value>ownCloud</value>
            </field>
            <field type="text-single" var="status">
                <value>false</value>
            </field>
            <field type="text-multi" var="requires">
                <value>PHP-MySQL-phpMyAdmin</value>
            </field>
            <field type="text-single" var="version">
                <value>7.0.2zypkg002</value>
            </field>
            <field type="text-multi" var="description">
                <value>This allows you to create and manage your private cloud.</value>
            </field>
        </item>
    </x>
    <thread>%s</thread>
</message>
EOT

#PACKAGE_ASK_REQUEST_SINGLE_SUCCESS % [ 'BOT_ID', 'DEVICE_ID', 'SESSION_ID']
PACKAGE_ASK_REQUEST_SINGLE_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
    <x xmlns="jabber:x:data" type="result">
        <title>bot_get_package_list</title>
        <item>
            <field type="text-single" var="package-name">
                <value>NZBGet</value>
            </field>
            <field type="text-single" var="status">
                <value>false</value>
            </field>
            <field type="text-multi" var="requires">
                <value></value>
            </field>
            <field type="text-single" var="version">
                <value>14.1zypkg003</value>
            </field>
            <field type="text-multi" var="description">
                <value>This package downloads .nzb file from Usenet. Default username:nzbget password:1234</value>
            </field>
        </item>
    </x>
    <thread>%s</thread>
</message>
EOT


#PACKAGE_ASK_REQUEST_EMPTY_SUCCESS % [ 'BOT_ID', 'DEVICE_ID', 'SESSION_ID']
PACKAGE_ASK_REQUEST_EMPTY_SUCCESS = <<EOT
<message to="%s" type="normal" from="%s" xml:lang="en">
    <x xmlns="jabber:x:data" type="result">
        <title>bot_get_package_list</title>
    </x>
    <thread>%s</thread>
</message>
EOT

# SET_PACKAGE_REQUEST_SUCCESS_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'SESSION_ID']
SET_PACKAGE_REQUEST_SUCCESS_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="result">
     <title>bot_set_package_list</title>
    </x>
    <thread>%s</thread>
</message>
EOT

# SET_PACKAGE_REQUEST_FAILUR_RESPONSE % ['BOT_ID', 'DEVICE_ID', 'SESSION_ID']
SET_PACKAGE_REQUEST_FAILUR_RESPONSE = <<EOT
<message to="%s" type="normal" from="%s" lang="en">
  <x xmlns="jabber:x:data" type="cancel">
     <title>bot_set_package_list</title>
     <item>
       <field var="package-name" type="text-single">
         <value>ownCloud</value>
       </field>
       <field var="ERROR_CODE" type="text-single">
         <value>488</value>
       </field>
     </item>
    </x>
    <thread>%s</thread>
</message>
EOT

