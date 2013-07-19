$:.unshift File.dirname(__FILE__)
require 'test_helper'

module Kytoon
module Providers
module CloudCue

class ServerTest < Test::Unit::TestCase

  include Kytoon::Providers::CloudCue

  def setup
    @tmp_dir=TmpDir.new_tmp_dir
    ServerGroup.data_dir=@tmp_dir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_gateway_server_rebuild_fails
    group=ServerGroup.from_xml(SERVER_GROUP_XML)
    server=group.server("login1")
    assert_raises(RuntimeError) do
        server.rebuild
    end
  end

  def test_rebuild
    group=ServerGroup.from_xml(SERVER_GROUP_XML)
    server=group.server("test1")
    Connection.stubs(:post).returns("")
    server.rebuild
  end

  def test_from_to_xml
    server=Server.from_xml(SERVER_XML)
    server=Server.from_xml(server.to_xml)
    assert_equal "db1", server.name
    assert_equal "blah", server.description
    assert_equal 1234, server.id
    assert_equal "888", server.cloud_server_id_number
    assert_equal 999, server.server_group_id
    assert_equal "10.119.225.116", server.internal_ip_addr
    assert_equal "123.100.100.100", server.external_ip_addr
    assert_equal "Online", server.status
  end

  def test_create

    Connection.stubs(:post).returns(SERVER_XML)
    server=Server.create(Server.from_xml(SERVER_XML))
    assert_equal "db1", server.name

  end

  def test_delete

    server=Server.from_xml(SERVER_XML)
    Connection.stubs(:delete).returns("")
    assert server.delete

  end

end

end
end
end
