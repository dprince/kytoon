require 'json'
require 'kytoon/util'
require 'fog'

module Kytoon

module Providers

module Openstack

# Openstack server group provider.
class ServerGroup

  @@connection=nil
  @@data_dir=File.join(KYTOON_PROJECT, "tmp", "openstack")

  def self.data_dir
    @@data_dir
  end

  def self.data_dir=(dir)
    @@data_dir=dir
  end

  CONFIG_FILE = KYTOON_PROJECT + File::SEPARATOR + "config" + File::SEPARATOR + "server_group.json"

  attr_accessor :id
  attr_accessor :name
  attr_accessor :use_security_groups

  def initialize(options={})
    @id = options[:id] || Time.now.to_f
    @name = options[:name]
    @use_security_groups = options[:use_security_groups]
    @servers=[]
    end

  def server(name)
    @servers.select {|s| s['hostname'] == name}[0] if @servers.size > 0
  end

  def servers
    @servers
  end

  def gateway_ip
    @servers.select {|s| s['gateway'] == 'true' }[0]['ip_address'] if @servers.size > 0
  end

  # generate a Server Group XML from server_group.json
  def self.from_json(json)

    json_hash=JSON.parse(json)

    sg=ServerGroup.new(
      :id => json_hash["id"],
      :name => json_hash["name"],
      :use_security_groups => json_hash["use_security_groups"]
    )
    json_hash["servers"].each do |server_hash|

      sg.servers << {
        'id' => server_hash['id'],
        'hostname' => server_hash['hostname'],
        'image_ref' => server_hash['image_ref'],
        'flavor_ref' => server_hash['flavor_ref'],
        'keypair_name' => server_hash['keypair_name'],
        'floating_ip' => server_hash['floating_ip'],
        'gateway' => server_hash['gateway'] || "false",
        'assign_floating_ip' => server_hash['assign_floating_ip'] || "false",
        'floating_ip' => server_hash['floating_ip'] || nil,
        'floating_ip_id' => server_hash['floating_ip_id'] || nil,
        'ip_address' => server_hash['ip_address']
      }
    end
    return sg
  end

  def pretty_print

    puts "Group ID: #{@id}"
    puts "name: #{@name}"
    puts "gateway IP: #{self.gateway_ip}"
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
        'use_security_groups' => @use_security_groups,
        'servers' => []
    }
    @servers.each do |server|
        sg_hash['servers'] << {'id' => server['id'], 'hostname' => server['hostname'], 'image_ref' => server['image_ref'], 'gateway' => server['gateway'], 'flavor_ref' => server['flavor_ref'], 'ip_address' => server['ip_address'], 'floating_ip' => server['floating_ip'], 'floating_ip_id' => server['floating_ip_id'], 'assign_floating_ip' => server['assign_floating_ip']}
    end

    FileUtils.mkdir_p(@@data_dir)
    File.open(File.join(@@data_dir, "#{@id}.json"), 'w') do |f|
      f.chmod(0600)
      f.write(sg_hash.to_json)
    end
  end

  def delete
    servers.each do |server|
      if server['assign_floating_ip'] == 'true' then
        ServerGroup.release_floating_ip(server)
      end
      ServerGroup.destroy_instance(server['id'])
    end

    #cleanup ssh keys
    private_ssh_key = File.join(@@data_dir, "#{@id}_id_rsa")
    public_ssh_key = File.join(@@data_dir, "#{@id}_id_rsa.pub")
    [private_ssh_key, public_ssh_key].each do |file|
      File.delete(file) if File.exists?(file)
    end

    out_file=File.join(@@data_dir, "#{@id}.json")
    File.delete(out_file) if File.exists?(out_file)
  end

  def self.create(sg)

    hosts_file_data = "127.0.0.1\tlocalhost localhost.localdomain\n"

    build_timeout = (Util.load_configs['openstack_build_timeout'] || 60).to_i

    base_key_name=File.join(@@data_dir, "#{sg.id}_id_rsa")
    Kytoon::Util.generate_ssh_keypair(base_key_name)
    private_ssh_key=IO.read(base_key_name)
    public_ssh_key=IO.read(base_key_name + ".pub")

    sg.servers.each do |server|
      server_id = create_instance(sg.id, server['hostname'], server['image_ref'], server['flavor_ref'], server['keypair_name']).id
      server['id'] = server_id

      if server['assign_floating_ip'] == 'true' then
        floating_data = assign_floating_ip(server_id)
        server['floating_ip_id'] = floating_data[0]
        server['floating_ip'] = floating_data[1]
      end

      sg.cache_to_disk
    end

    begin
      Timeout::timeout(build_timeout) do
        ips = get_server_ips
        sg.servers.each do |server|
          server_ip = ips[server['id']]
          if server['assign_floating_ip'] == 'true' then
            server['ip_address'] = server['floating_ip']
          else
            server['ip_address'] = server_ip
          end
          sg.cache_to_disk
          hosts_file_data += "#{server_ip}\t#{server['hostname']}\n"
        end
      end
    rescue Timeout::Error => te
      raise KytoonException, "Timeout building server group."
    end

    puts "Copying hosts files..."

gateway_ssh_config = %{
[ -d .ssh ] || mkdir .ssh
cat > .ssh/id_rsa <<-EOF_CAT
#{private_ssh_key}
EOF_CAT
chmod 600 .ssh/id_rsa
cat > .ssh/id_rsa.pub <<-EOF_CAT
#{public_ssh_key}
EOF_CAT
chmod 600 .ssh/id_rsa.pub
cat > .ssh/config <<-EOF_CAT
StrictHostKeyChecking no
EOF_CAT
chmod 600 .ssh/config
}

node_ssh_config= %{
[ -d .ssh ] || mkdir .ssh
cat > .ssh/authorized_keys <<-EOF_CAT
#{public_ssh_key}
EOF_CAT
chmod 600 .ssh/authorized_keys
}

    # now that we have IP info copy hosts files into the servers
    sg.servers.each do |server|
      ping_test(server['ip_address'])
      Kytoon::Util.remote_exec(%{
cat > /etc/hosts <<-EOF_CAT
#{hosts_file_data}
EOF_CAT
hostname "#{server['hostname']}"
if [ -f /etc/sysconfig/network ]; then
  sed -e "s|^HOSTNAME.*|HOSTNAME=#{server['hostname']}|" -i /etc/sysconfig/network
fi
#{server['gateway'] == 'true' ? gateway_ssh_config : node_ssh_config}
      }, server['ip_address']) do |ok, out|
        if not ok
          puts out
          raise KytoonException, "Failed to copy host file to instance #{server['hostname']}."
        end
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

  def self.init_connection
    configs = Util.load_configs
    if @@connection.nil? then
      @connection = Fog::Compute.new(
        :provider           => :openstack,
        :openstack_auth_url  => configs['openstack_url'],
        :openstack_username => configs['openstack_username'],
        :openstack_api_key => configs['openstack_password'],
        :openstack_service_name => configs['openstack_service_name'],
        :openstack_service_type => configs['openstack_service_type'],
        :openstack_region => configs['openstack_region']
      )
    else
      @@connection
    end
  end

  def self.create_instance(group_id, hostname, image_ref, flavor_ref, keypair_name)

    configs = Util.load_configs
    conn = self.init_connection

    options = {
      :name => "#{group_id}_#{hostname}",
      :image_ref => image_ref,
      :flavor_ref => flavor_ref}

    keypair_name = configs['openstack_keypair_name'] if keypair_name.nil?
    if not keypair_name.nil? and not keypair_name.empty? then
      options.store(:key_name, keypair_name)
    else
      options.store(:personality,
      :personality => [
        {'path' => "/root/.ssh/authorized_keys",
         'contents' => IO.load(Util.public_key_path)}
      ])
    end

    server = conn.servers.create(options)
    server

  end

  def self.assign_floating_ip(server_id)

    conn = self.init_connection

    data = conn.allocate_address.body
    address_id = data['floating_ip']['id']
    address_ip = data['floating_ip']['ip']

    configs = Util.load_configs
    network_name = configs['openstack_network_name'] || 'public'

    # wait for instance to obtain fixed ip
    1.upto(60) do
      server = conn.servers.get(server_id)
      if server.addresses and server.addresses[network_name] and server.addresses[network_name].detect {|a| a['version'] == self.default_ip_type} then
        break
      end
    end

    conn.associate_address(server_id, address_ip).body
    [address_id, address_ip]

  end

  def self.release_floating_ip(server)

    conn = self.init_connection

    address_ip = server['floating_ip']
    address_id = server['floating_ip_id']

    conn.disassociate_address(server['id'], address_ip)

    # wait for address to disassociate (instance_id should be nil)
    1.upto(30) do
      floating_ips = conn.list_all_addresses.body['floating_ips']
      break if floating_ips.detect {|f| f['id'] == address_id and f['instance_id' == nil]}
    end

    begin
      conn.release_address(address_id)
    rescue Fog::Compute::OpenStack::NotFound
      puts "Unable to release IP address #{address_ip}: Not Found."
    end

  end

  def self.default_ip_type()
    ip_type = Util.load_configs['openstack_ip_type'] || 4
    ip_type.to_i
  end

  def self.get_server_ips()

    ips = {}
    configs = Util.load_configs

    network_name = configs['openstack_network_name'] || 'public'

    conn = self.init_connection
    all_active = false
    until all_active do
      all_active = true
      conn.servers.each do |server|
        if ips[server.id].nil? then
          server = conn.servers.get(server.id)
          if server.state == 'ACTIVE' then
            addresses = server.addresses[network_name].select {|a| a['version'] == self.default_ip_type}
            ips[server.id] = addresses[0]['addr']
          else
            all_active = false
          end
        end
      end
    end

    ips

  end

  def self.ping_test(ip_addr)

    ping_timeout = (Util.load_configs['openstack_ping_timeout'] || 60).to_i

    begin
      ping = self.default_ip_type == 6 ? 'ping6' : 'ping'
      ping_command = "#{ping} -c 1 #{ip_addr} > /dev/null 2>&1"
      Timeout::timeout(ping_timeout) do
        while(1) do
          return true if system(ping_command)
        end
      end
    rescue Timeout::Error => te
      raise KytoonException, "Timeout pinging server: #{ping_command}"
    end

    return false

  end

  def self.destroy_instance(uuid)
    begin
      conn = self.init_connection
      server = conn.servers.get(uuid)
      if server then
        server.destroy
      else
        puts "Server #{uuid} no longer exists."
      end
    rescue Exception => e
      puts "Error deleting server: #{e.message}"
    end
  end

end

end

end

end
