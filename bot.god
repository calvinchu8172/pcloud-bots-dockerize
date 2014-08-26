$stdout.sync = true

require 'yaml'
require 'net/smtp'
require 'net/pop'
require 'tlsmail'

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

God::Contacts::Email.defaults do |d|
  Net::SMTP.enable_tls(OpenSSL::SSL::VERIFY_NONE)
  d.from_email = 'bot-notification@%s' % config['mail_domain']
  d.from_name = 'bot-notification'
  d.delivery_method = :smtp
  d.server_host = 'email-smtp.us-west-2.amazonaws.com'
  d.server_port = 587
  d.server_auth = :plain
  d.server_domain = config['mail_domain']
  d.server_user = config['mail_user']
  d.server_password = config['mail_pw']
end

config['notify_list'].each do |note|
  God.contact(:email) do |c|
    c.name = note['name']
    c.group = 'developers'
    c.to_email = note['email']
  end
end

i = 0
XMPP_CONFIG.each do |c|
  God.watch do |w|
    w.name = "personal-cloud-bot-%d" % i
    w.start = "#{PATH}bot_main_controller.rb -u #{c["jid"]} -p #{c["pw"]}"
    w.keepalive
    w.log = "#{PATH}bot.log"
    w.err_log = "#{PATH}bot.err"

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