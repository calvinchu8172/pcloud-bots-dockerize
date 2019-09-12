$stdout.sync = true

require 'yaml'
require 'net/smtp'
require 'net/pop'
require 'tlsmail'
#require_relative './lib/bot_xmpp_db_access'

GOD_CONFIG_FILE = './config/god_config.yml'
config_file = File.join(File.dirname(__FILE__), GOD_CONFIG_FILE)
config = YAML.load(File.read(config_file))

PATH = config['path']
XMPP_CONFIG = config['xmpp_config']

Net::SMTP.class_eval do
  def initialize_with_starttls(*args)
    initialize_without_starttls(*args)
    enable_starttls
  end

  alias_method :initialize_without_starttls, :initialize
  alias_method :initialize, :initialize_with_starttls
end

# God::Contacts::Email.defaults do |d|
#   Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
#   d.from_email = 'bot-notification@%s' % config['mail_domain']
#   d.from_name = 'bot-notification'
#   d.delivery_method = :smtp
#   d.server_host = 'email-smtp.us-east-1.amazonaws.com'
#   d.server_port = 587
#   d.server_auth = :plain
#   d.server_domain = config['mail_domain']
#   d.server_user = config['mail_user']
#   d.server_password = config['mail_pw']
# end

# config['notify_list'].each do |note|
#   God.contact(:email) do |c|
#     c.name = note['name']
#     c.group = 'developers'
#     c.to_email = note['email']
#   end
# end

bots_revision = `cd #{File.dirname(__FILE__)} && git rev-parse HEAD`.strip

#@xmpp_db = BotXmppDBAccess.new

BOT_LIST = XMPP_CONFIG['bot_list']

i = 0
BOT_LIST.each do |c|
  God.watch do |w|
    username = c["username"]
    #jid      = username + '@' + XMPP_CONFIG['domain'] + '/' + XMPP_CONFIG['resource']
    #password = @xmpp_db.db_reset_password(username)

    w.name = "personal-cloud-bot-%d" % i
    #w.start   = "#{PATH}bot_main_controller.rb -u #{jid} -p #{password} -r #{bots_revision}"
    w.start   = "#{PATH}bot_main_controller.rb -u #{username} -r #{bots_revision}"

    w.keepalive( :memory_max => 500.megabytes,
                 :cpu_max => 50.percent )
    
    w.log     = "#{PATH}log/bot.log"
    w.err_log = "#{PATH}log/bot.err"

    w.start_if do |on|
      on.condition(:process_running) do |e|
        e.interval = 2.seconds
        e.running = false
        e.notify = {:contacts => ['developers'], :priority => 1, :category => 'production'}
      end
    end
  end
  i += 1
end

God.watch do |w|
  w.name = "device"
  w.start = "ruby #{PATH}device_echo.rb"
  w.keepalive
  w.log     = "#{PATH}log/device.log"
  w.err_log = "#{PATH}log/device.err"
end
