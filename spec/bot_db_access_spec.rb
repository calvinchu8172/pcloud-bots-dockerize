require_relative '../lib/bot_db_access'
require 'yaml'

#DB_CONFIG_FILE = '../config/bot_db_config.yml'

describe BotDBAccess do
  let(:db){BotDBAccess.new}
  let(:user){User.find_or_create_by({email: 'test@ecoworkinc.com', display_name: 'test'})}
  let(:device){db.db_device_insert({serial_number: 'NS123456789',
                                    mac_address: '000000000000',
                                    firmware_version: '1.000.000',
                                    product_id: '26'})}

  after(:all) do
    user = User.find_by({email: 'test@ecoworkinc.com', display_name: 'test'}  )
    user.destroy!

    device = Devices.find_by({serial_number: 'NS123456789',
                              mac_address: '000000000000',
                              firmware_version: '1.000.000',
                              product_id: '26'})
    device.destroy   if !device.nil?
  end

  it 'Config file check' do
    config_file = File.join(File.dirname(__FILE__), DB_CONFIG_FILE)
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
      expect(db).to be_an_instance_of(BotDBAccess)
  end

  context "About User table" do
    it 'Access user table' do
      expect(user).to respond_to(:id)

      invalidUser = db.db_user_access(0)
      expect(invalidUser).to be_nil
    end
  end

  context "About Pair & Pair Session table" do
    pair_methods = ['db_pairing_access',
                    'db_pairing_insert',
                    'db_pairing_update',
                    'db_pairing_delete']

    pair_id = nil
    pair_data = {user_id: 'test@ecoworkinc.com', device_id: 123456789}

    device_data = {serial_number: 'NS123456789', mac_address: '000000000000', firmware_version: '1.000.000', product_id: '26'}

    it 'Existence of Pair & Pair Session methods check' do
      pair_methods.each do |x|
        expect(db).to respond_to(x.to_sym)
      end
    end

    it 'Access non-exist record from Pairing table' do
      pair = db.db_pairing_access(pair_data)
      expect(pair).to be_nil
    end

    it 'Add new record into Pairing table' do
      # Add pairing record
      pair = db.db_pairing_insert(user.id, device.id)
      expect(pair).to respond_to(:id)

      access = db.db_pairing_access({id: pair.id})
      expect(access).to respond_to(:id)

      isDeleted = db.db_pairing_delete(pair.id)
      expect(isDeleted).to be true
    end

    it 'Update Pairing record' do
      # Add pairing record
      pair = db.db_pairing_insert(user.id, device.id)
      expect(pair).to respond_to(:id)

      # update pairing record
      pair_data = {id: pair.id, device_id: device.id}
      isSuccess = db.db_pairing_update(pair_data)
      expect(isSuccess).to be true

      # Check pairing record
      pair = db.db_pairing_access({id: pair.id})
      expect(pair).to respond_to(:id)
      expect(pair.device_id.to_d).to eq(device.id)

      pair_data[:id] = 0
      isSuccess = db.db_pairing_update(pair_data)
      expect(isSuccess).to be false

      # Recovery
      isDeleted = db.db_pairing_delete(pair.id)
      expect(isDeleted).to be true
    end

    it 'Delete Pairing record' do
      # Add pairing record
      pair = db.db_pairing_insert(user.id, device.id)
      expect(pair).to respond_to(:id)

      # Delete pairing record
      isSuccess = db.db_pairing_delete(pair.id)
      expect(isSuccess).to be true
    end
  end

  context "About Device & DeviceSession table" do
    device_methods = ['db_device_access',
                      'db_device_insert',
                      'db_device_update',
                      'db_device_delete']

    device_id = nil

    it 'Existence of Device & Device Session methods check' do
      device_methods.each do |x|
        expect(db).to respond_to(x.to_sym)
      end
    end

    it 'Access non-exist record from Device table' do
      data = {serial_number: 'NS123456789', mac_address: '0e:11:83:t6', firmware_version: '1.000.000', product_id: Product.first.id}
      device = db.db_device_access(data)
      expect(device).to be_nil
    end

    it 'Add new record into Device table re-test access method' do
      data = {serial_number: 'NS123456789', mac_address: '0e:11:83:t6', firmware_version: '1.000.000', product_id: Product.first.id}
      device = db.db_device_insert(data)
      expect(device).to respond_to(:id)
      device_id = device.id

      access = db.db_device_access({id: device_id})
      expect(access).to respond_to(:id)
    end

    it 'Update Device record' do
      data = {id: device_id, serial_number: 'NS123456789', mac_address: '0e:11:83:t6', firmware_version: '1.000.001'}
      isSuccess = db.db_device_update(data)
      expect(isSuccess).to be true

      data = {id: 0, serial_number: 'NS123456789', mac_address: '0e:11:83:t6', firmware_version: '1.000.001'}
      isSuccess = db.db_device_update(data)
      expect(isSuccess).to be false
    end

    it 'Delete Device record' do
      isSuccess = db.db_device_delete(device_id)
      expect(isSuccess).to be true
      device_id = nil

      isSuccess = db.db_device_delete(0)
      expect(isSuccess).to be false
    end
  end

  context "About DDNS & DDNS Session table" do
    ddns_methods = ['db_ddns_access',
                    'db_ddns_insert',
                    'db_ddns_update',
                    'db_ddns_delete']

    ddns_id = nil

    it 'Existence of DDNS & DDNS Session methods check' do
      ddns_methods.each do |x|
        expect(db).to respond_to(x.to_sym)
      end
    end

    it 'Access non-exist record from DDNS table' do
      index = Time.now.to_i
      host_name = "ut%s" % index
      device_id = index
      #puts "%s.#{Domain.first.domain_name}" % host_name 
      ddns = db.db_ddns_access({
                                device_id: device_id,
                                ip_address: '10.1.1.111',
                                full_domain: "%s.#{Domain.first.domain_name}" % host_name
                              })
      expect(ddns).to be_nil
    end

    it 'Add new record into DDNS table and re-test access method' do
      index = Time.now.to_i
      host_name = "ut%s" % index
      device = db.db_device_insert({serial_number: index, mac_address: '0e:11:83:t6', firmware_version: '1.000.000', product_id: Product.first.id})

      data = {
        device_id: device.id,
        ip_address: '10.1.1.111',
        full_domain: "%s.#{Domain.first.domain_name}" % host_name
      }

      ddns = db.db_ddns_insert(data)
      expect(ddns).to respond_to(:id)

      access = db.db_ddns_access({id: ddns.id})

      expect(access).to respond_to(:id)
      expect(access.full_domain).to eq(data[:full_domain])
      expect(access.device_id).to eq(data[:device_id])
      expect(access.ip_address).to eq(data[:ip_address])

      isDeleted = db.db_ddns_delete(access.id) && db.db_device_delete(device.id)
      expect(isDeleted).to be true
    end

    it 'Update DDNS record' do
      index = Time.now.to_i
      host_name = "ut%s" % index

      data = {
        device_id: device.id,
        ip_address: '10.1.1.111',
        full_domain: "%s.#{Domain.first.domain_name}" % host_name
      }

      ddns = db.db_ddns_insert(data)
      expect(ddns).to respond_to(:id)

      sleep(1.2)

      index = Time.now.to_i
      host_name = "ut%s" % index
      ddns = {
        id: ddns.id,
        ip_address: '10.1.1.112',
        full_domain: "%s.#{Domain.first.domain_name}" % host_name
      }

      isSuccessUpdate = db.db_ddns_update(ddns)

      access = db.db_ddns_access({id: ddns[:id]})

      expect(isSuccessUpdate).to be true
      expect(access).to respond_to(:id)
      expect(access.hostname).to eq(host_name)
      expect(access.ip_address).to eq(ddns[:ip_address])

      isDeleted = db.db_ddns_delete(access.id) && db.db_device_delete(device.id)
      expect(isDeleted).to be true
    end

    it 'Delete DDNS record' do
      index = Time.now.to_i
      host_name = "ut%s" % index
      device = db.db_device_insert({serial_number: index, mac_address: '0e:11:83:t6', firmware_version: '1.000.000', product_id: Product.first.id})

      data = {
        device_id: device.id,
        ip_address: '10.1.1.111',
        full_domain: "%s.#{Domain.first.domain_name}" % host_name
      }

      ddns = db.db_ddns_insert(data)

      isDeleted = db.db_ddns_delete(ddns.id) && db.db_device_delete(device.id)
      expect(isDeleted).to be true

      isSuccess = db.db_ddns_delete(ddns)
      expect(isSuccess).to be false
      expect(ddns).not_to be_nil
    end
  end

  context "About User info access" do

    it 'Retrieve user local by device id' do
      index = Time.now.to_i
      device = db.db_device_insert({serial_number: index, mac_address: '0e:11:83:t6', firmware_version: '1.000.000', product_id: Product.first.id})
      pairing = db.db_pairing_insert(user.id, device.id)
      user_local = db.db_retrive_user_local_by_device_id(device.id)
      isDeleted = db.db_pairing_delete(pairing.id) && db.db_device_delete(device.id)

      expect(pairing).not_to be_nil
      expect(user_local).to be_an_instance_of(String)
      expect(isDeleted).to be true
    end

    it 'Retrieve user email by device id' do
      index = Time.now.to_i
      device = db.db_device_insert({serial_number: index, mac_address: '0e:11:83:t6', firmware_version: '1.000.000', product_id: Product.first.id})
      pairing = db.db_pairing_insert(user.id, device.id)
      user_email = db.db_retrive_user_email_by_device_id(device.id)
      isDeleted = db.db_pairing_delete(pairing.id) && db.db_device_delete(device.id)

      expect(pairing).not_to be_nil
      expect(user_email).to be_an_instance_of(String)
      expect(isDeleted).to be true
    end
  end
end