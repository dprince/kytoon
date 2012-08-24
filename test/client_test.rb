$:.unshift File.dirname(__FILE__)
require 'test_helper'
require 'kytoon/providers/cloud_servers_vpc'

module Kytoon
module Providers
module CloudServersVPC

class ClientTest < Test::Unit::TestCase

  include Kytoon::Providers::CloudServersVPC

  def setup
    @tmp_dir=TmpDir.new_tmp_dir
    Client.data_dir=@tmp_dir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_new
    client=Client.new(:name => "test", :description => "zz", :status => "Pending")
    assert_equal "test", client.name
    assert_equal "zz", client.description
    assert_equal 0, client.vpn_network_interfaces.size
  end

  def test_from_xml
    client=Client.from_xml(CLIENT_XML)
    assert_equal "local", client.name
    assert_equal "Toolkit Client: local", client.description
    assert_equal 5, client.id
    assert_equal 11, client.server_group_id
    vni=client.vpn_network_interfaces[0] 
    assert_not_nil vni.client_key
    assert_not_nil vni.client_cert
    assert_not_nil vni.ca_cert
  end

  def test_client_to_and_from_xml
    client=Client.from_xml(CLIENT_XML)
    xml=client.to_xml
    assert_not_nil xml
    client=Client.from_xml(xml) 
    assert_equal "local", client.name
    assert_equal "Toolkit Client: local", client.description
    assert_equal 5, client.id
    assert_equal 11, client.server_group_id
    vni=client.vpn_network_interfaces[0] 
    assert_not_nil vni.client_key
    assert_not_nil vni.client_cert
    assert_not_nil vni.ca_cert
  end

  def test_get

    tmp_dir=TmpDir.new_tmp_dir
    File.open("#{tmp_dir}/5.xml", 'w') do |f|
        f.write(CLIENT_XML)
    end
    Client.data_dir=tmp_dir

    Connection.stubs(:get).returns(CLIENT_XML)

    # should raise exception if no ID is set and doing a remote lookup
    assert_raises(RuntimeError) do
      Client.get
    end

    client=Client.get(:id => "1234")
    assert_not_nil client
    assert_equal "Toolkit Client: local", client.description

    client=Client.get(:id => "5", :source => "cache")
    assert_not_nil client
    assert_equal "Toolkit Client: local", client.description

    #nonexistent group from cache
    ENV['GROUP_ID']="1234"
    assert_raises(RuntimeError) do
      Client.get(:source => "cache")
    end

    #invalid get source
    assert_raises(RuntimeError) do
      Client.get(:id => "5", :source => "asdf")
    end

  end

  def test_delete

    client=Client.from_xml(CLIENT_XML)
    client.delete
    assert_equal false, File.exists?(File.join(Client.data_dir, "#{client.id}.xml"))

  end

  def test_create

    Connection.stubs(:post).returns(CLIENT_XML)
    client=Client.create(ServerGroup.from_xml(SERVER_GROUP_XML), "local")
    assert_equal "local", client.name

  end

end

end
end
end
