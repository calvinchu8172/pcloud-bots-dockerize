require_relative '../lib/bot_xmpp_controller'
require_relative '../lib/bot_xmpp_db_access'
require_relative '../lib/bot_xmpp_health_check_template'
require 'xmpp4r/client'
require 'multi_xml'
require 'eventmachine'
require 'pry'
include Jabber

FLUENT_BOT_SYSINFO = "bot.sys-info"
FLUENT_BOT_SYSERROR = "bot.sys-error"
FLUENT_BOT_SYSALERT = "bot.sys-alert"
FLUENT_BOT_FLOWINFO = "bot.flow-info"
FLUENT_BOT_FLOWERROR = "bot.flow-error"
FLUENT_BOT_FLOWALERT = "bot.flow-alert"

BOT_ROUTE_CONFIG_FILE = '../config/bot_route_config.yml'

Jabber::debug = FALSE


describe 'XMPPController health check function' do
  config_file = File.join(File.dirname(__FILE__), BOT_ROUTE_CONFIG_FILE)
  config = YAML.load(File.read(config_file))

  let(:xmpp_db) {BotXmppDBAccess.new}
  let(:domain_name) {config["zones_info"][0]["name"]}
  xmpp_db = BotXmppDBAccess.new

  #for test
  bot_xmpp_user = XMPP_User.find_by(username: "bot")
  bot_xmpp_user = XMPP_User.create(username: "bot", password: "bot") if bot_xmpp_user.nil?
  bot_xmpp_account = bot_xmpp_user.username
  bot_xmpp_domain = "localhost"

  bot_health_check_xmpp_user = XMPP_User.find_by(username: "bot_health_check")
  bot_health_check_xmpp_user = XMPP_User.create(username: "bot_health_check", password: "123456") if bot_health_check_xmpp_user.nil?
  bot_health_check_xmpp_account = "#{bot_health_check_xmpp_user.username}@#{bot_xmpp_domain}/device"
  bot_health_check_xmpp_account_node = bot_health_check_xmpp_user.username
  bot_health_check_xmpp_password = xmpp_db.db_reset_password( bot_health_check_xmpp_account_node )
  #for test

  jid = JID.new(bot_health_check_xmpp_account)
  client = Client.new(jid)

  xmpp_connect_ready = FALSE

  xmppThread=Thread.new{
    XMPPController.new(bot_xmpp_account, bot_xmpp_domain)
    XMPPController.run
  }
  xmppThread.abort_on_exception = TRUE

  XMPPController.when_ready { xmpp_connect_ready = TRUE }

  while !xmpp_connect_ready
    puts '    Waiting XMPP connection ready'
    sleep(2)
  end
  puts '    XMPP connection ready'

  before(:all) do
    # it 'Connection to remote XMPP server' do
    client.connect
    sleep(3)
    isAuth = client.auth(bot_health_check_xmpp_password)
    expect(isAuth).to be true
    bot_xmpp_account = bot_xmpp_account + '@' + bot_xmpp_domain + '/device' if isAuth

    # 模擬Bot_Health_Check對XMPPController送出HEALTH_CHECK_SEND_RESPONSE的message，然後驗證接收到的結果正確不正確。
    to = bot_xmpp_account
    from = bot_health_check_xmpp_account
    @health_check_send_time = Time.now.to_i
    @bot_receive_time = 0
    @bot_send_time = 0
    @health_check_receive_time = 0
    @thread = Time.now.to_i
    health_check_msg = HEALTH_CHECK_SEND_RESPONSE % [to, from, @health_check_send_time, @bot_receive_time, @bot_send_time, @health_check_receive_time, @thread]
    client.send health_check_msg
    # end
  end

  x = nil
  callbackThread = Thread.new{
    EM.run{
      client.add_message_callback do |msg|
        # x = msg.respond_to?(:x) && !msg.x.nil? ? msg.x : msg.to_s
        x = msg.respond_to?(:message) && !msg.message.nil? ? msg.message : msg.to_s
      end
    }
  }
  callbackThread.abort_on_exception = TRUE

  # XMPPController正確收到訊息的話，message handler會收到HEALTH_CHECK_SEND_RESPONSE的message，
  # 然後message handler呼叫XMPPCrontroller的send_request方法，送出HEALTH_CHECK_SUCCESS_RESPONSE給Bot_Health_Check，
  # 這一段為驗證Bot_Health_check收到HEALTH_CHECK_SUCCESS_RESPONSE的格式是否正確。
  context 'Receive RESULT message' do
    it 'Bot_Health_Check receives HEALTH_CHECK_SUCCESS_RESPONSE' do
      x = nil
      i = 0
      while x.nil? && i < 200
        sleep(0.1)
        i += 1
      end

      MultiXml.parser = :rexml
      xml = MultiXml.parse(x.to_s)

      title = xml['message']['x']['title']
      to = xml['message']['to']
      from = xml['message']['from']
      health_check_send_time_after = xml["message"]["x"]["item"]["field"][0]["value"]
      bot_receive_time_after = xml["message"]["x"]["item"]["field"][1]["value"]
      bot_send_time_after = xml["message"]["x"]["item"]["field"][2]["value"]
      health_check_receive_time_after = xml["message"]["x"]["item"]["field"][3]["value"]
      thread_after = xml['message']['thread']

      expect(xml).to be_an_instance_of(Hash)
      expect(title).to eq('bot_health_check_success')
      expect(to).to eq(bot_health_check_xmpp_account) #結果目的 to 應該要是bot_health_check_xmpp_account
      expect(from).to eq(bot_xmpp_account) #成功訊息是由bot送出
      expect(health_check_send_time_after).to eq(@health_check_send_time.to_s) #bot_health_check_send_time理當要一樣
      expect(bot_receive_time_after).to be >= @health_check_send_time.to_s #若有延遲，bot收到的時間會大於bot_health_check送出時間
      expect(bot_send_time_after).to be >= @bot_receive_time_after.to_s #若有延遲，bot送出時間會大於bot收到訊息的時間
      expect(health_check_receive_time_after).to eq('0') #bot_health_check收到的時間為bot_health_check那邊記錄，bot這邊不會寫入這時間，所以應為預設值"0"
      expect(thread_after).to eq(@thread.to_s) #同一支訊息的thread一定要一樣
    end # it
  end # context

end