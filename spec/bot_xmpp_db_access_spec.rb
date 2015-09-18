require_relative '../lib/bot_xmpp_db_access'
require 'yaml'

#DB_CONFIG_FILE = '../config/bot_db_config.yml'

describe BotXmppDBAccess do
  let(:db){BotXmppDBAccess.new}
  let(:user){XMPP_User.find_or_create_by({username: 'test@ecoworkinc.com', password: '123'})}

  after(:all) do
    user = XMPP_User.find_by({username: 'test@ecoworkinc.com'}  )
    user.destroy!
  end

  it 'Config file check' do
    config_file = File.join(File.dirname(__FILE__), XMPP_DB_CONFIG_FILE)
    config = YAML.load(File.read(config_file))
    expect(config).to be_an_instance_of(Hash)

    expect(config).to have_key('db_host')
    expect(config).to have_key('db_socket')
    expect(config).to have_key('db_name')
    expect(config).to have_key('db_userid')
    expect(config).to have_key('db_userpw')
    expect(config).to have_key('db_pool')

    expect(config['db_host']).not_to eq('xxx')
    expect(config['db_socket']).not_to eq('xxx')
    expect(config['db_name']).not_to eq('xxx')
    expect(config['db_userid']).not_to eq('xxx')
    expect(config['db_userpw']).not_to eq('xxx')
    expect(config['db_pool']).not_to eq('xxx')
  end

  it 'Initialize DB class' do
      expect(db).to be_an_instance_of(BotXmppDBAccess)
  end

  context "About User table" do
    it 'Reset user password' do
      user.username = 'test@ecoworkinc.com'
      db.db_reset_password(user.username)
      user = XMPP_User.find_by({username: 'test@ecoworkinc.com'}  )
      expect(user.password).not_to eq('123') 
    end
  end
end