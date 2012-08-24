$:.unshift File.dirname(__FILE__)
require 'test_helper'

require 'tempfile'
require 'kytoon/providers/cloud_servers_vpc'

module Kytoon
module Vpn

class VpnNetworkManagerTest < Test::Unit::TestCase

  include Kytoon::Providers::CloudServersVPC

  def setup
    @group=ServerGroup.from_xml(SERVER_GROUP_XML)
    @client=Client.from_xml(CLIENT_XML)
    tmpdir=TmpDir.new_tmp_dir
    File.open(File.join(tmpdir, "gconftool-2"), 'w') do |f|
      f.write("#!/bin/bash\nexit 0")
      f.chmod(0755)
    end
    ENV['PATH']=tmpdir+":"+ENV['PATH']
    @vpn_net_man = VpnNetworkManager.new(@group, @client)
  end

  def teardown
    @vpn_net_man.delete_certs
  end

  def test_configure_gconf
    assert @vpn_net_man.configure_gconf
  end

  def test_ip_to_integer
    assert_equal 16782252, @vpn_net_man.ip_to_integer("172.19.0.1")
  end

end

end
end
