$stdout.sync = true
PATH = "xxx"

God.watch do |w|
  w.name = "personal-cloud"
  w.start = "#{PATH}bot_main_controller.rb"
  w.keepalive
  w.log = "#{PATH}bot.log"
  w.err_log = "#{PATH}bot.err"
end
