#!/usr/bin/env ruby
#Version: 2.6.5
$stdout.sync = true
Encoding.default_external = Encoding::UTF_8

require 'yaml'
GOD_CONFIG_FILE = './config/god_config.yml'
config_file = File.join(File.dirname(__FILE__), GOD_CONFIG_FILE)
config = YAML.load(File.read(config_file))
PATH = config['path']

require_relative 'lib/bot_db_access'
require_relative 'lib/bot_queue_access'
require_relative 'lib/bot_redis_access'
require_relative 'lib/bot_xmpp_controller'
require_relative 'lib/bot_logger'

require_relative 'lib/bot_xmpp_health_check_template'

xmpp_connect_ready = FALSE
threads = Array.new


FLUENT_BOT_SYSINFO = "bot.sys-info"
FLUENT_BOT_SYSERROR = "bot.sys-error"
FLUENT_BOT_SYSALERT = "bot.sys-alert"
FLUENT_BOT_FLOWINFO = "bot.flow-info"
FLUENT_BOT_FLOWERROR = "bot.flow-error"
FLUENT_BOT_FLOWALERT = "bot.flow-alert"


#LOGGER.error("This is an error log...")
#LOGGER.warn("This is an warn log...")


def get_xmpp_config
  input = ARGV
  account = nil

  god_config_file = './config/god_config.yml'
  config_file = File.join(File.dirname(__FILE__), god_config_file)
  god_config = YAML.load(File.read(config_file))
  #password = nil
  #length = input.length - 1

  for i in 0..(input.length - 1)
    option = input[i]
    account = input[i + 1] if '-u' == option
    #password = input[i + 1] if '-p' == option
  end
  #return {jid: account, pw: password}
  return {jid: account ,domain: god_config['xmpp_config']['domain']}
end

XMPP_CONFIG = get_xmpp_config

jobThread = Thread.new {
    LOGGER.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                             direction: 'N/A',
                                             to: 'N/A',
                                             from: 'N/A',
                                             id: 'N/A',
                                             full_domain: 'N/A',
                                             message:"XMPP Controll running ...",
                                             data: 'N/A'})
    XMPPController.new(XMPP_CONFIG[:jid] , XMPP_CONFIG[:domain])
    XMPPController.run
}
jobThread.abort_on_exception = TRUE
threads << jobThread

XMPPController.when_ready { xmpp_connect_ready = TRUE }
db_conn = BotDBAccess.new
rd_conn = BotRedisAccess.new

while !xmpp_connect_ready
  LOGGER.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                           direction: 'N/A',
                                           to: 'N/A',
                                           from: 'N/A',
                                           id: 'N/A',
                                           full_domain: 'N/A',
                                           message:"Waiting XMPP connection ready ...",
                                           data: 'N/A'})
  sleep(2)
end
LOGGER.post(FLUENT_BOT_SYSINFO, {event: 'SYSTEM',
                                         direction: 'N/A',
                                         to: 'N/A',
                                         from: 'N/A',
                                         id: 'N/A',
                                         full_domain: 'N/A',
                                         message:"XMPP connection ready",
                                         data: 'N/A'})

def worker(sqs, db_conn, rd_conn)
  sqs.sqs_listen{
    |job, data|
    begin
    case job

      when 'pairing' then
        device_id = data[:device_id]
        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'PAIR',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: device_id,
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of pairing",
                                                  data: data})

        device = rd_conn.rd_device_session_access(device_id)
        pair = rd_conn.rd_pairing_session_access(device_id)
        xmpp_account = nil != device ? device["xmpp_account"] : nil
        expire_time = nil != pair ? (pair["expire_at"].to_i - Time.now.to_i) : 0
        info = {xmpp_account: xmpp_account.to_s,
                device_id: device_id,
                expire_time: expire_time}

        XMPPController.send_request(KPAIR_START_REQUEST, info) if !xmpp_account.nil? && !pair.nil?

      when 'unpair' then

        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'UNPAIR',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: 'N/A',
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of unpair", data: data})
        device_id = data[:device_id]
        device = rd_conn.rd_device_session_access(device_id)
        xmpp_account = !device.nil? ? device["xmpp_account"] : ''
        rd_conn.rd_unpair_session_insert(device_id) if !device.nil?
        ddns = db_conn.db_ddns_access({device_id: device_id})
        full_domain = !ddns.nil? ? ddns.full_domain : nil

        info = {xmpp_account: xmpp_account,
                session_id: device_id,
                full_domain: full_domain
                }

        XMPPController.send_request(KUNPAIR_ASK_REQUEST, info) if !device.nil?

      when 'upnp_submit' then

        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of upnp-submit", data: data})
        xmpp_account = nil
        service_list = nil
        session_id = data[:session_id]
        upnp = rd_conn.rd_upnp_session_access(session_id)
        device = rd_conn.rd_device_session_access(upnp["device_id"]) if !upnp.nil?
        xmpp_account = device["xmpp_account"] if !device.nil?
        service_list = upnp["service_list"].to_s if !upnp.nil?
        #language = db_conn.db_retrive_user_local_by_device_id(upnp["device_id"]) if !upnp.nil?

        field_item = ""

        if valid_json? service_list then
          service_list_json = JSON.parse(service_list)
          service_list_json.each do |item|
            service_name = item["service_name"].to_s
            status = item["status"].to_s
            enabled = item["enabled"].to_s
            description = item["description"].to_s
            path = item["path"].to_s
            lan_port = item["lan_port"].to_i
            wan_port = item["wan_port"].to_i

            field_item += UPNP_FIELD_ITEM % [service_name, status, enabled, description, path, lan_port, wan_port]
          end
        end

        info = {xmpp_account: xmpp_account.to_s,
                language: 'en',
                session_id: session_id,
                field_item: field_item}
        XMPPController.send_request(KUPNP_SETTING_REQUEST, info) if !xmpp_account.nil?

      when 'upnp_query' then

        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'UPNP',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of upnp-query", data: data})

        xmpp_account = nil
        session_id = data[:session_id]
        upnp = rd_conn.rd_upnp_session_access(session_id)
        device = rd_conn.rd_device_session_access(upnp["device_id"]) if !upnp.nil?
        xmpp_account = device["xmpp_account"] if !device.nil?
        #language = db_conn.db_retrive_user_local_by_device_id(upnp["device_id"]) if !upnp.nil?
        info = {xmpp_account: xmpp_account.to_s,
                language: 'en',
                session_id: data[:session_id]}

        XMPPController.send_request(KUPNP_ASK_REQUEST, info) if !xmpp_account.nil?
      when 'package_submit' then
        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'PACKAGE',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of PACKAGE SUBMIT", data: data})
        xmpp_account = nil
        package_list = nil
        session_id = data[:session_id]
        package = rd_conn.rd_package_session_access(session_id)
        device = rd_conn.rd_device_session_access(package["device_id"]) if !package.nil?
        xmpp_account = device["xmpp_account"] if !device.nil?
        package_list = package["package_list"].to_s if !package.nil?
        field_item = ""

        if valid_json? package_list then
          package_list_json = JSON.parse(package_list)
          package_list_json.each do |item|
            next if item["enabled"] == item["status"]
            package_name = item["package_name"].to_s
            enabled = item["enabled"].to_s
            field_item += PACKAGE_FIELD_ITEM % [package_name,  enabled]
          end
        end
        info = {xmpp_account: xmpp_account.to_s,
                session_id: session_id,
                field_item: field_item}
        XMPPController.send_request(KPACKAGE_SETTING_REQUEST, info) if !xmpp_account.nil?


      when 'package_query' then
        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'PACKAGE',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of package-query", data: data})

        xmpp_account = nil
        session_id = data[:session_id]
        package = rd_conn.rd_package_session_access(session_id)

        device = rd_conn.rd_device_session_access(package["device_id"]) if !package.nil?

        xmpp_account = device["xmpp_account"] if !device.nil?
        info = {xmpp_account: xmpp_account.to_s,
                session_id: data[:session_id]}

        XMPPController.send_request(KPACKAGE_ASK_REQUEST, info) if !xmpp_account.nil?


      when 'ddns' then
        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'DDNS',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of DDNS-query", data: data})

        device = nil
        xmpp_account = nil
        session_id = data["session_id"]
        xmpp_account = data["xmpp_account"]
        device_id = data["device_id"]
        device_ip = data["ip"]
        full_domain = data["full_domain"]
        #if( xmpp_account.nil? )
        #  ddns_session = rd_conn.rd_ddns_session_access(session_id)
        #  device = rd_conn.rd_device_session_access(ddns_session["device_id"]) if !ddns_session.nil?
        #  xmpp_account = device["xmpp_account"] if !device.nil?
        #end
        info = {xmpp_account: xmpp_account.to_s,
                session_id: session_id,
                device_id: device_id,
                ip: device_ip.to_s,
                full_domain: full_domain.to_s}
        XMPPController.send_request(KDDNS_SETTING_REQUEST, info) if !xmpp_account.nil? && !device_id.nil? && !device_ip.nil? && !full_domain.nil?

      when 'cancel' then
        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'CANCEL',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:tag],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of cancel", data: data})

        tag = data[:tag]
        title = data[:title]
        if 'pairing' == title then
          device_id = tag
          device = nil
          device = rd_conn.rd_device_session_access(device_id)
          xmpp_account = !device.nil? ? device["xmpp_account"] : nil
          info = {xmpp_account: xmpp_account.to_s,
                  tag: device_id,
                  title: 'pair'}
          XMPPController.send_request(KSESSION_CANCEL_REQUEST, info) if !xmpp_account.nil?
        end

        if ['get_upnp_service', 'set_upnp_service'].include?(title) then
          index = tag
          upnp = rd_conn.rd_upnp_session_access(index)
          device_id = !upnp.nil? ? upnp["device_id"] : nil

          device = nil
          device = rd_conn.rd_device_session_access(device_id)
          xmpp_account = !device.nil? ? device["xmpp_account"] : nil
          info = {xmpp_account: xmpp_account.to_s,
                  tag: device_id,
                  title: title}
          XMPPController.send_request(KSESSION_CANCEL_REQUEST, info) if !xmpp_account.nil?
        end

      when 'create_permission' then

        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'PERMISSION',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of Create-permission", data: data})
        session_id         = data[:session_id]

        permission_session = rd_conn.rd_permission_session_access(session_id)

        device_id          = permission_session["device_id"]
        device             = rd_conn.rd_device_session_access(device_id) if !permission_session.nil?

        xmpp_account       = device["xmpp_account"] if !device.nil?

        info = {device_id:      device_id,
                xmpp_account:   xmpp_account.to_s,
                session_id: session_id,
                permission_session: permission_session}

        XMPPController.send_request(KPERMISSION_ASK_REQUEST, info) if !xmpp_account.nil? && !permission_session.nil?

      when 'device_info' then

        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'DEVICE-INFOMATION',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of Device Information", data: data})

        session_id          = data[:session_id]
        device_info_session = rd_conn.rd_device_info_session_access(session_id)
        device_id           = device_info_session["device_id"]

        device              = rd_conn.rd_device_session_access(device_id) if !device_info_session.nil?
        xmpp_account        = device["xmpp_account"] if !device.nil?

        info = {session_id:     session_id,
                device_id:      device_id,
                xmpp_account:   xmpp_account.to_s}

        XMPPController.send_request(KDEVICE_INFO_ASK_REQUEST, info) if !xmpp_account.nil? && !device_info_session.nil?

    when 'led_indicator' then

        LOGGER.post(FLUENT_BOT_FLOWINFO, {event: 'LED INDICATOR',
                                                  direction: 'Portal->Bot',
                                                  to: XMPP_CONFIG[:jid],
                                                  from: 'N/A',
                                                  id: data[:session_id],
                                                  full_domain: 'N/A',
                                                  message:"Get SQS queue of led indicator", data: data})
        device = nil
        xmpp_account = nil
        session_id = data[:session_id]
        led_session = rd_conn.led_indicator_session_access(session_id)
        device = rd_conn.rd_device_session_access(led_session["device_id"]) if !led_session.nil?
        xmpp_account = device["xmpp_account"] if !device.nil?


        info = {xmpp_account: xmpp_account,
                session_id: session_id}

        XMPPController.send_request(KLED_INDICATOR_REQUEST, info) if !device.nil?
    end

    rescue Exception => error

      LOGGER.post(FLUENT_BOT_SYSALERT, {message:error.message, inspect: error.inspect, backtrace: error.backtrace})
    end
    job = nil
    data = nil
  }
end

sqs = BotQueueAccess.new

60.times do |d|
  sqsThread = Thread.new{ worker(sqs, db_conn, rd_conn) }
  sqsThread.abort_on_exception = TRUE
  threads << sqsThread
end

worker(sqs, db_conn, rd_conn)