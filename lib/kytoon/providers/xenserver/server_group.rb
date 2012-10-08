require 'json'
require 'fileutils'
require 'kytoon/util'
require 'base64'
require 'ipaddr'

module Kytoon

module Providers

module Xenserver
# All in one XenServer server group provider.
#
# Required setup:
# 1) add your ssh key to the XenServer box.
#
# 2) Pre-download any .xva images you'd like to use. These images *must*
#    have the OpenStack guest agent installed (including Xen Guest Tools).
#
# 3) Generate an ssh keypair on your XenServer host.
#
# 4) Add an ip to the private Xen bridge you'd like to use for instances.
#    This IP should match the range you'd like to use in your server group
#    config file. Example:
#      ip addr add 192.168.0.1/24 brd 192.168.0.255 scope global dev xenbr1
#
class ServerGroup

  @@data_dir=File.join(KYTOON_PROJECT, "tmp", "xenserver")

  def self.data_dir
    @@data_dir
  end

  def self.data_dir=(dir)
    @@data_dir=dir
  end

  CONFIG_FILE = KYTOON_PROJECT + File::SEPARATOR + "config" + File::SEPARATOR + "server_group.json"

  attr_accessor :id
  attr_accessor :name
  attr_accessor :gateway_ip
  attr_accessor :netmask
  attr_accessor :gateway
  attr_accessor :broadcast
  attr_accessor :network_type
  attr_accessor :bridge
  attr_accessor :public_ip_bridge
  attr_accessor :dns_nameserver

  def initialize(options={})
    @id = options[:id] || Time.now.to_i
    @name = options[:name]
    @netmask = options[:netmask]
    @gateway = options[:gateway]
    @broadcast = options[:broadcast]
    @network_type = options[:network_type]
    @bridge = options[:bridge]
    @public_ip_bridge = options[:public_ip_bridge]
    @dns_nameserver = options[:dns_nameserver]
    @gateway_ip = options[:gateway_ip]
    @gateway_ip = ENV['GATEWAY_IP'] if @gateway_ip.nil?
    raise ConfigException, "Please specify a GATEWAY_IP" if @gateway_ip.nil?

    @servers=[]
    end

  def server(name)
    @servers.select {|s| s['hostname'] == name}[0] if @servers.size > 0
  end

  def servers
    @servers
  end

  def gateway_ip
    @gateway_ip
  end

  # generate a Server Group XML from server_group.json
  def self.from_json(json)

    json_hash=JSON.parse(json)

    sg=ServerGroup.new(
      :id => json_hash["id"],
      :name => json_hash["name"],
      :netmask => json_hash['netmask'],
      :gateway => json_hash['gateway'],
      :gateway_ip => json_hash['gateway_ip'],
      :broadcast => json_hash['broadcast'],
      :dns_nameserver => json_hash['dns_nameserver'],
      :network_type => json_hash['network_type'],
      :public_ip_bridge => json_hash['public_ip_bridge'],
      :bridge => json_hash['bridge']
    )
    json_hash["servers"].each do |server_hash|
      sg.servers << {
        'hostname' => server_hash['hostname'],
        'ip_address' => server_hash['ip_address'],
        'mac' => server_hash['mac'],
        'image_path' => server_hash['image_path']
      }
    end
    return sg

  end

  def pretty_print

    puts "Group ID: #{@id}"
    puts "name: #{@name}"
    puts "Servers:"
    servers.each do |server|
      puts "\tname: #{server['hostname']}"
      puts "\t--"
    end

  end

  def server_names

    names=[]  

    servers.each do |server|
      if block_given? then
        yield server['hostname']
      else
        names << server['hostname']
      end  
    end

    names
    
  end

  def cache_to_disk

    sg_hash = {
        'id' => @id,
        'name' => @name,
        'netmask' => @netmask,
        'gateway' => @gateway,
        'gateway_ip' => @gateway_ip,
        'broadcast' => @broadcast,
        'dns_nameserver' => @dns_nameserver,
        'network_type' => @network_type,
        'public_ip_bridge' => @public_ip_bridge,
        'bridge' => @bridge,
        'servers' => []
    }
    @servers.each do |server|
        sg_hash['servers'] << {'hostname' => server['hostname'], 'ip_address' => server['ip_address'], 'image_path' => server['image_path'], 'mac' => server['mac']}
    end

    FileUtils.mkdir_p(@@data_dir)
    File.open(File.join(@@data_dir, "#{@id}.json"), 'w') do |f|
      f.chmod(0600)
      f.write(sg_hash.to_json)
    end
  end

  def delete
    ServerGroup.cleanup_instances(@gateway_ip)
    out_file=File.join(@@data_dir, "#{@id}.json")
    File.delete(out_file) if File.exists?(out_file)
  end

  def self.create(sg)
    sg.cache_to_disk
    init_host(sg)
    status, host_ssh_public_key = Kytoon::Util.remote_exec(%{
if [ -f /root/.ssh/id_rsa.pub ]; then
  cat /root/.ssh/id_rsa.pub
elif [ -f /root/.ssh/id_dsa.pub ]; then
  cat /root/.ssh/id_dsa.pub
else
  exit 1
fi
    }, sg.gateway_ip)
    sg.servers.each do |server|
        create_instance(sg.gateway_ip, server['image_path'], server['hostname'], server['mac'], sg.bridge, host_ssh_public_key)
        network_type = sg.network_type
        if network_type == 'static' then
            configure_static_networking(sg.gateway_ip, server['hostname'], server['ip_address'], sg.netmask, sg.gateway, sg.broadcast, server['mac'], sg.dns_nameserver)
        else
          raise "Unsupported network type '#{sg.network_type}'"
        end
    end
    sg
  end

  def self.get(options={})
    id = options[:id]
    if id.nil? then
      group=ServerGroup.most_recent
      raise NoServerGroupExists, "No server group files exist." if group.nil?
      id=group.id
    end

    out_file=File.join(@@data_dir, "#{id}.json")
    raise NoServerGroupExists, "No server group files exist." if not File.exists?(out_file)
    ServerGroup.from_json(IO.read(out_file))
  end

  def self.index(options={})

    server_groups=[]
    Dir[File.join(ServerGroup.data_dir, '*.json')].each do  |file|
      server_groups << ServerGroup.from_json(IO.read(file))
    end
    server_groups

  end

  def self.most_recent
    server_groups=[]
    Dir[File.join(@@data_dir, "*.json")].each do  |file|
      server_groups << ServerGroup.from_json(IO.read(file))
    end
    if server_groups.size > 0 then
      server_groups.sort { |a,b| b.id <=> a.id }[0]
    else
      nil
    end
  end

  def self.init_host(sg)

    cidr = IPAddr.new(sg.netmask).to_i.to_s(2).count("1")

    hosts_file_data = "127.0.0.1\tlocalhost localhost.localdomain\n"
    sg.servers.each do |server|
      hosts_file_data += "#{server['ip_address']}\t#{server['hostname']}\n"
    end

    Kytoon::Util.remote_exec(%{
# Add first IP to bridge
if ! ip a | grep #{sg.gateway}/#{cidr} | grep #{sg.bridge}; then
  ip a add #{sg.gateway}/#{cidr} dev #{sg.bridge}
fi

cat > /etc/hosts <<-EOF_CAT
#{hosts_file_data}
EOF_CAT
# FIXME... probably a bit insecure but most people are probably using
# boxes behind another firewall anyway.
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT
iptables -t nat -A POSTROUTING -o #{sg.public_ip_bridge} -j MASQUERADE
echo 1 > /proc/sys/net/ipv4/ip_forward
    }, sg.gateway_ip)
  end

  def self.create_instance(gw_ip, image_path, hostname, mac, xen_bridge='xenbr1', ssh_public_key=nil)
    file_data = Base64.encode64("/root/.ssh/authorized_keys,#{ssh_public_key}")

    Kytoon::Util.remote_exec(%{
      BASE_VM_NAME=$(basename #{image_path})
      BASE_VM_UUID=$(xe vm-list name-label=$BASE_VM_NAME | grep uuid | sed -e 's|.*: ||')

      if [ -z "$BASE_VM_UUID" ]; then
        # create base vm for future use
        BASE_UUID=$(xe vm-import filename=#{image_path})
        xe vm-param-set name-label=$BASE_VM_NAME uuid=$BASE_UUID
        xe vm-param-set other-config:kytoon_base_vm=true uuid=$BASE_UUID
      fi

      UUID=$(xe vm-clone vm=$BASE_VM_NAME new-name-label=${BASE_VM_NAME}_new)
      xe vm-param-remove param-name=other-config param-key=kytoon_base_vm uuid=$UUID
      xe vm-param-set name-label=#{hostname} uuid=$UUID
      NETWORK_UUID=$(xe network-list bridge=#{xen_bridge} | grep -P "^uuid" | cut -f2 -d: | cut -f2 -d" ")
      xe vif-destroy uuid=$VIF_UUID &> /dev/null
      for VIF_UUID in $(xe vif-list vm-uuid=$UUID | grep uuid | sed -e 's|.*: ||'); do
        echo "Destroying Xen VIF uuid: $VIF_UUID"
        xe vif-destroy uuid=$VIF_UUID &> /dev/null
      done
      xe vif-create vm-uuid=$UUID mac=#{mac} network-uuid=$NETWORK_UUID device=0 &> /dev/null
      xe vm-start uuid=$UUID &> /dev/null

      # inject ssh from host
      DOMID=$(xe vm-param-get uuid=$UUID param-name="dom-id")
      xenstore-rm -s /local/domain/$DOMID/data/guest/ssh_key 2> /dev/null
      xenstore-write -s /local/domain/$DOMID/data/host/ssh_key '{"name": "injectfile", "value": "#{file_data}"}'
      until [ -n "$INJECT_RETVAL" ]; do
        INJECT_RETVAL=$(xenstore-read -s /local/domain/$DOMID/data/guest/ssh_key 2> /dev/null)
      done
      xenstore-rm -s /local/domain/$DOMID/data/host/ssh_key

    }, gw_ip) do |ok, out|
      if not ok
        puts out
        raise KytoonException, "Failed to create instance #{hostname}."
      end
    end
  end

  def self.cleanup_instances(gw_ip)
    Kytoon::Util.remote_exec(%{
      for UUID in $(xe vm-list is-control-domain=false | grep uuid | sed -e 's|.*: ||'); do
        # destroy all instances except the basevm's
        if ! xe vm-param-get param-name=other-config uuid=$UUID | grep -c kytoon_base_vm; then
          echo "Destroying Xen instance uuid: $UUID"
          xe vm-shutdown force=true uuid=$UUID
          xe vm-uninstall uuid=$UUID force=true
        fi
      done
      for VDI_UUID in $(xe vdi-list read-only=false | grep -v sr-uuid | grep uuid | sed -e 's|.*: ||'); do
        # destroy all vdi's which aren't in use
        IN_USE=$(xe vbd-list vdi-uuid=$VDI_UUID | grep vdi-uuid | grep -c $VDI_UUID)
        if [[ "$IN_USE" -eq "0" ]]; then
          echo "removing VDI: $VDI_UUID"
          xe vdi-destroy uuid=$VDI_UUID
        fi
      done
    }, gw_ip) do |ok, out|
      if not ok
        puts out
        raise "Failed to cleanup instances."
      end
    end
  end

  def self.configure_static_networking(gw_ip, hostname, ip_address, netmask, gateway, broadcast, mac, dns_nameserver)

    # networking
    network_info = {
      "label" => "public",
      "broadcast" => broadcast,
      "ips" => [{
      "ip" => ip_address,
      "netmask" => netmask,
      "enabled" => "1"}],
      "mac" => mac,
      "dns" => [dns_nameserver],
      "gateway" => gateway
    }

    Kytoon::Util.remote_exec(%{
      UUID=$(xe vm-list name-label=#{hostname} | grep uuid | sed -e 's|.*: ||')
      DOMID=$(xe vm-param-get uuid=$UUID param-name="dom-id")
      xenstore-write -s /local/domain/$DOMID/vm-data/hostname '#{hostname}'
      xenstore-write -s /local/domain/$DOMID/vm-data/networking/123_nw_info '#{network_info.to_json}'

      xenstore-write -s /local/domain/$DOMID/data/host/123_reset_nw '{"name": "resetnetwork", "value": ""}'
      xenstore-rm -s /local/domain/$DOMID/data/guest/123_reset_nw 2> /dev/null
      until [ -n "$NW_RETVAL" ]; do
        NW_RETVAL=$(xenstore-read -s /local/domain/$DOMID/data/guest/123_reset_nw 2> /dev/null)
      done
      xenstore-rm -s /local/domain/$DOMID/data/host/123_reset_nw
      xe vm-reboot uuid=$UUID &> /dev/null
      COUNT=0
      until ping -c 1 #{hostname} &> /dev/null; do
        COUNT=$(( $COUNT + 1 ))
        [ $COUNT -eq 10 ] && break
      done
      until ssh -o ConnectTimeout=1 #{hostname} &> /dev/null; do
        COUNT=$(( $COUNT + 1 ))
        [ $COUNT -eq 20 ] && break
        sleep 1
      done
      ssh #{hostname} bash <<-EOF_SSH_BASH
hostname #{hostname}
      EOF_SSH_BASH
      scp /etc/hosts #{hostname}:/etc/hosts
    }, gw_ip) do |ok, out|
      puts out
      if not ok
        puts out
        raise "Failed to setup static networking for #{hostname}."
      end
    end

  end

end

end

end

end
