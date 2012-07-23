$:.unshift File.dirname(__FILE__)
require 'test_helper'

require 'tempfile'

module Kytoon

class SshUtilTest < Test::Unit::TestCase

  def test_remove_known_hosts_ip

    t=Tempfile.new('ssh_test')
    t.write(%{login,172.19.0.1 ssh-rsa AAAAB3NzaC1yc2EAAAABIwAAAQEAu1Xfhjj0hZwDIXWa6Gd/Qk/S9VwO5ec9+u6CMLMteQY4seeXmpu643k8zCa6yLuDXyzucknfrsxtOKJVQ6F5glXW6+Ko/zPiPNQbeC6GIKDs2a3m6A5OJSqRHqoy0RTJu11Acs3tkWUgmvBKFX7jxEZuHJM1kI0/xP0JlO0zOVr8+9Wg6Zy5KfVnEsgbdaEvpk3Rrtt5Lm42w/uxvPTFY7AWBhUfloYqBQrX6zd8d17jHLCnukHmvdR7eVGihXREtvDjX4ycG1o5/9amLWR0ELVFkFiXPHyWCuyl21j5uI7Ro9P2pga5ypnDB+N1BjFJHSMMofT40XOBkzAxBUrLgw==\n})
    t.flush
    SshUtil.remove_known_hosts_ip('login,172.19.0.1', t.path)
    assert_equal "", IO.read(t.path)

  end

end

end
