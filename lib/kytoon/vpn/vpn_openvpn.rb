module Kytoon
module Vpn
class VpnOpenVpn < VpnConnection

  def initialize(group, client = nil)
    super(group, client)
  end

  def connect
    create_certs

    @up_script=get_cfile('up.bash')
    File.open(@up_script, 'w') do |f|
        f << <<EOF_UP
#!/bin/bash

# setup routes
/sbin/route add #{@group.vpn_network.chomp("0")+"1"} dev \$dev
/sbin/route add -net #{@group.vpn_network} netmask 255.255.128.0 gw #{@group.vpn_network.chomp("0")+"1"}

mv /etc/resolv.conf /etc/resolv.conf.bak
egrep ^search /etc/resolv.conf.bak | sed -e 's/search /search #{@group.domain_name} /' > /etc/resolv.conf
echo 'nameserver #{@group.vpn_network.chomp("0")+"1"}' >> /etc/resolv.conf
grep ^nameserver /etc/resolv.conf.bak >> /etc/resolv.conf
EOF_UP
      f.chmod(0700)
    end
    @down_script=get_cfile('down.bash')
    File.open(@down_script, 'w') do |f|
        f << <<EOF_DOWN
#!/bin/bash
mv /etc/resolv.conf.bak /etc/resolv.conf
EOF_DOWN
      f.chmod(0700)
    end

    @config_file=get_cfile('config')
    File.open(@config_file, 'w') do |f|
      f << <<EOF_CONFIG
client
dev #{@group.vpn_device}
proto #{@group.vpn_proto}

#Change my.publicdomain.com to your public domain or IP address
remote #{@group.gateway_ip} 1194

resolv-retry infinite
nobind
persist-key
persist-tun

script-security 2

ca #{@ca_cert}
cert #{@client_cert}
key #{@client_key}

ns-cert-type server

route-nopull

comp-lzo

verb 3
up #{@up_script}
down #{@down_script}
EOF_CONFIG
      f.chmod(0600)
    end

    disconnect if File.exist?(get_cfile('openvpn.pid'))
    out=%x{sudo openvpn --config #{@config_file} --writepid #{get_cfile('openvpn.pid')} --daemon}
    retval=$?
    if retval.success? then
      poll_vpn_interface
      puts "OK."
    else
      raise "Failed to create VPN connection: #{out}"
    end
  end

  def disconnect
    raise "Not running? No pid file found!" unless File.exist?(get_cfile('openvpn.pid'))
    pid = File.read(get_cfile('openvpn.pid')).chomp
    system("sudo kill -TERM #{pid}")
    File.delete(get_cfile('openvpn.pid'))
  end

  def connected?
    system("/sbin/route -n | grep #{@group.vpn_network.chomp("0")+"1"} &> /dev/null")
  end

  def clean
    delete_certs
  end

  private
  def poll_vpn_interface
    interface_name=@group.vpn_device+"0"
    1.upto(30) do |i|
      break if system("/sbin/ifconfig #{interface_name} > /dev/null 2>&1")
      if i == 30 then
        disconnect
        raise "Failed to connect to VPN."
      end
      sleep 0.5
    end
  end

end
end
end
