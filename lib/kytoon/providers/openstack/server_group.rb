require 'json'
require 'kytoon/util'
require 'openstack/compute'

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

  def initialize(options={})
    @id = options[:id] || Time.now.to_i
    @name = options[:name]
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
      :name => json_hash["name"]
    )
    json_hash["servers"].each do |server_hash|

      sg.servers << {
        'id' => server_hash['id'],
        'hostname' => server_hash['hostname'],
        'image_ref' => server_hash['image_ref'],
        'flavor_ref' => server_hash['flavor_ref'],
        'keypair' => server_hash['keypair'],
        'gateway' => server_hash['gateway'] || "false",
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
        'servers' => []
    }
    @servers.each do |server|
        sg_hash['servers'] << {'id' => server['id'], 'hostname' => server['hostname'], 'image_ref' => server['image_ref'], 'gateway' => server['gateway'], 'flavor_ref' => server['flavor_ref'], 'ip_address' => server['ip_address']}
    end

    FileUtils.mkdir_p(@@data_dir)
    File.open(File.join(@@data_dir, "#{@id}.json"), 'w') do |f|
      f.chmod(0600)
      f.write(sg_hash.to_json)
    end
  end

  def delete
    servers.each do |server|
      ServerGroup.destroy_instance(server['id'])
    end
    out_file=File.join(@@data_dir, "#{@id}.json")
    File.delete(out_file) if File.exists?(out_file)
  end


  def self.create(sg)

    hosts_file_data = "127.0.0.1\tlocalhost localhost.localdomain\n"

    build_timeout = (Util.load_configs['openstack_build_timeout'] || 60).to_i

    sg.servers.each do |server|
      server_id = create_instance(sg.id, server['hostname'], server['image_ref'], server['flavor_ref']).id

      server['id'] = server_id
      sg.cache_to_disk
    end

    begin
      Timeout::timeout(build_timeout) do
        ips = get_server_ips
        sg.servers.each do |server|
          server_ip = ips[server['id']]
          server['ip_address'] = server_ip
          sg.cache_to_disk
          hosts_file_data += "#{server_ip}\t#{server['hostname']}\n"
        end
      end
    rescue Timeout::Error => te
      raise KytoonException, "Timeout building server group."
    end


    puts "Copying hosts files..."
    #now that we have IP info copy hosts files into the servers
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
      @@connection = OpenStack::Compute::Connection.new(
        :username => configs['openstack_username'],
        :api_key => configs['openstack_password'],
        :auth_url => configs['openstack_url'],
        :retry_auth => false)
    else
      @@connection
    end
  end

  def self.create_instance(group_id, hostname, image_ref, flavor_ref)

    ssh_public_key = Util.public_key_path
    configs = Util.load_configs

    conn = self.init_connection

    options = {
      :name => "#{group_id}_#{hostname}",
      :imageRef => image_ref,
      :flavorRef => flavor_ref,
      :personality => {ssh_public_key => "/root/.ssh/authorized_keys"},
      :is_debug => true}

    key_name = configs['openstack_key_name']
    if not key_name.nil? and not key_name.empty? then
      options.store(:key_name, key_name)
    end

    conn.create_server(options)

  end

  def self.default_ip_type()
    ip_type = Util.load_configs['openstack_ip_type'] || 4
    ip_type.to_i
  end

  def self.get_server_ips()

    ips = {}

    conn = self.init_connection
    all_active = false
    until all_active do
      all_active = true
      conn.servers.each do |server|
        server = conn.server(server[:id])
        if server.status == 'ACTIVE' and ips[server.id].nil? then
          addresses = server.addresses[:public].select {|a| a.version == self.default_ip_type}
          ips[server.id] = addresses[0].address
        else
          all_active = false
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
      conn.server(uuid).delete!
    rescue Exception => e
      puts "Error deleting server: #{e.message}"
    end
  end

end

end

end

end
