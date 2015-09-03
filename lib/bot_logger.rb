require 'process_safe_logger'
class ProcessSafeLogger
  def self.custom_level(tag)
    SEV_LABEL << tag 
    idx = SEV_LABEL.size - 1 
    define_method(tag.downcase.gsub(/\W+/, '_').to_sym) do |progname, &block|
      add(idx, nil, progname, &block)
    end 
  end
  def post(level ,message)
  	#message = message.to_json
  	#message = message.gsub!(/\\u([0-9a-z]{4})/) {|s| [$1.to_i(16)].pack("U")}
  	#message = message.gsub('Device-\u003eBot' ,'Device->Bot')
  	#message = message.gsub('Bot-\u003eDevice' ,'Bot->Device')
  	message = JSON.generate(message, :ascii_only => true)
  	case level
  	when FLUENT_BOT_SYSINFO
  		self.sys_info( message )
  	when FLUENT_BOT_SYSERROR
  		self.sys_error( message )
  	when FLUENT_BOT_SYSALERT
  		self.sys_alert( message )
  	when FLUENT_BOT_FLOWINFO
  		self.flow_info( message )
  	when FLUENT_BOT_FLOWERROR
  		self.flow_error( message )
  	when FLUENT_BOT_FLOWALERT
  		self.flow_alert( message )
  	end
  end
  # now add levels like this:
  custom_level 'sys_info'
  custom_level 'sys_error'
  custom_level 'sys_alert'
  custom_level 'flow_info'
  custom_level 'flow_error'
  custom_level 'flow_alert'
end


#logger setting
log_file = PATH + 'log/bot.log'
LOGGER = ProcessSafeLogger.new( log_file )

LOGGER.formatter = proc do  |severity, datetime, progname, msg|
    date_format = Time.now.utc.iso8601
    severity = severity.sub( '_' , '-' )
    "#{date_format}\tbot.#{severity}\t#{msg}\n"
end