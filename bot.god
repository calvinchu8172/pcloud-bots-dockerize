$stdout.sync = true
PATH = "xxx"
XMPP_CONFIG = [{jid: xxx, pw: xxx}]

i = 0
XMPP_CONFIG.each do |c|
  God.watch do |w|
    w.name = "personal-cloud-%d" % i
    w.start = "#{PATH}bot_main_controller.rb -u #{c[:jid]} -p #{c[:pw]}"
    w.keepalive
    w.log = "#{PATH}bot.log"
    w.err_log = "#{PATH}bot.err"
  end
  i += 1
end