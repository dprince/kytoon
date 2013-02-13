require 'json'
require 'kytoon/util'
require 'rexml/document'
require 'rexml/xpath'
require 'timeout'

module Kytoon

module Providers

module Libvirt
# All in one Libvirt server group provider.
#
# Required setup:
# 1) Libvirt domain XML file or running domain to clone.
#
# 2) Generate an ssh keypair to be injected into the image.
#
class ServerGroup

  KIB_PER_GIG = 1048576

  @@data_dir=File.join(KYTOON_PROJECT, "tmp", "libvirt")

  def self.data_dir
    @@data_dir
  end

  def self.data_dir=(dir)
    @@data_dir=dir
  end

  CONFIG_FILE = KYTOON_PROJECT + File::SEPARATOR + "config" + File::SEPARATOR + "server_group.json"

  attr_accessor :id
  attr_accessor :name
  attr_accessor :use_sudo

  def initialize(options={})
    @id = options[:id] || Time.now.to_f
    @name = options[:name]
    @use_sudo = options[:use_sudo]
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

    configs = Util.load_configs
    use_sudo = ENV['LIBVIRT_USE_SUDO'] || configs['libvirt_use_sudo'].to_s

    sg=ServerGroup.new(
      :id => json_hash["id"],
      :name => json_hash["name"],
      :use_sudo => use_sudo
    )
    json_hash["servers"].each do |server_hash|

      sg.servers << {
        'hostname' => server_hash['hostname'],
        'memory' => server_hash['memory'],
        'original' => server_hash['original'],
        'original_xml' => server_hash['original_xml'],
        'create_cow' => server_hash['create_cow'],
        'selinux_enabled' => server_hash['selinux_enabled'],
        'disk_path' => server_hash['disk_path'],
        'ip_address' => server_hash['ip_address'],
        'gateway' => server_hash['gateway'] || "false"
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
        sg_hash['servers'] << {'hostname' => server['hostname'], 'memory' => server['memory'], 'gateway' => server['gateway'], 'original' => server['original'], 'original_xml' => server['original_xml'], 'create_cow' => server['create_cow'], 'disk_path' => server['disk_path'], 'selinux_enabled' => server['selinux_enabled'], 'ip_address' => server['ip_address']}
    end

    FileUtils.mkdir_p(@@data_dir)
    File.open(File.join(@@data_dir, "#{@id}.json"), 'w') do |f|
      f.chmod(0600)
      f.write(sg_hash.to_json)
    end
  end

  def delete
    sudo = @use_sudo =~ /(true|t|yes|y|1)$/i ? "sudo" : ""
    servers.each do |server|
      ServerGroup.cleanup_instances(@id, server['hostname'], server['disk_path'], sudo)
    end
    out_file=File.join(@@data_dir, "#{@id}.json")
    File.delete(out_file) if File.exists?(out_file)

    #cleanup ssh keys
    private_ssh_key = File.join(@@data_dir, "#{@id}_id_rsa")
    public_ssh_key = File.join(@@data_dir, "#{@id}_id_rsa.pub")
    [private_ssh_key, public_ssh_key].each do |file|
      File.delete(file) if File.exists?(file)
    end

  end

  def self.create(sg)

    ssh_public_key = Kytoon::Util.load_public_key

    base_key_name=File.join(@@data_dir, "#{sg.id}_id_rsa")
    Kytoon::Util.generate_ssh_keypair(base_key_name)
    private_ssh_key=IO.read(base_key_name)
    public_ssh_key=IO.read(base_key_name + ".pub")

    sudo = sg.use_sudo =~ /(true|t|yes|y|1)$/i ? "sudo" : ""
    hosts_file_data = "127.0.0.1\tlocalhost localhost.localdomain\n"
    sg.servers.each do |server|

      image_dir=server['image_dir'] || '/var/lib/libvirt/images'
      disk_path=File.join(image_dir, "#{sg.id}_#{server['hostname']}.img")
      server['disk_path'] = disk_path

      instance_ip = create_instance(sg.id, server['hostname'], server['memory'], server['original'], server['original_xml'], disk_path, server['create_cow'], server['selinux_enabled'], ssh_public_key, sudo)
      server['ip_address'] = instance_ip
      hosts_file_data += "#{instance_ip}\t#{server['hostname']}\n"
      sg.cache_to_disk
    end

    puts "Copying hosts files..."

gateway_ssh_config = %{
mkdir -p .ssh
cat > .ssh/id_rsa <<-EOF_CAT
#{private_ssh_key}
EOF_CAT
chmod 600 .ssh/id_rsa
cat > .ssh/id_rsa.pub <<-EOF_CAT
#{public_ssh_key}
EOF_CAT
chmod 644 .ssh/id_rsa.pub
cat > .ssh/config <<-EOF_CAT
StrictHostKeyChecking no
EOF_CAT
chmod 600 .ssh/config
}

node_ssh_config= %{
mkdir -p .ssh
cat >> .ssh/authorized_keys <<-EOF_CAT
#{public_ssh_key}\n
EOF_CAT
chmod 600 .ssh/authorized_keys
}

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
#{server['gateway'] == 'true' ? gateway_ssh_config : ""}
#{node_ssh_config}
      }, server['ip_address']) do |ok, out|
        if not ok
          puts out
          raise KytoonException, "Failed to copy host file to instance #{server['hostname']}."
        end
      end
    end

    sg
  end

  def self.default_ip_type()
    ip_type = Util.load_configs['libvirt_ip_type'] || 4
    ip_type.to_i
  end

  def self.ping_test(ip_addr)

    ping_timeout = (Util.load_configs['libvirt_ping_timeout'] || 60).to_i

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

  # Determine the path of the source disk to be used
  def self.source_disk_filename(original, original_xml)
    if original and not original.empty? then
      dom = REXML::Document.new(%x{virsh dumpxml nova1})
    else
      dom = REXML::Document.new(IO.read(original_xml))
    end
    REXML::XPath.each(dom, "//disk[1]/source") do |source_xml|
      return source_xml.attributes['file']
    end
    raise KytoonException, "Unable to find disk path for instance."
  end

  def self.create_instance(group_id, inst_name, memory_gigs, original, original_xml, disk_path, create_cow, selinux_enabled, ssh_public_key, sudo)

    selinux_enabled = selinux_enabled =~ /(true|t|yes|y|1)$/i ? "true" : ""

    puts "Creating instance: #{inst_name}"
    instance_memory = (KIB_PER_GIG * memory_gigs.to_f).to_i
    original_disk_path = source_disk_filename(original, original_xml) #cow only
    domain_name="#{group_id}_#{inst_name}"

    out = %x{
if [ -n "$DEBUG" ]; then
set -x
fi
if [ -n "#{original_xml}" ]; then
  ORIGIN="--original-xml #{original_xml}"
elif [ -n "#{original}" ]; then
  ORIGIN="--original #{original}"
else
    { echo "Please specify 'original' or 'original_xml'."; exit 1; }
fi

if [ -n "#{create_cow}" ]; then

  #{sudo} virt-clone --connect=qemu:///system \
    --name '#{domain_name}' \
    --file '#{disk_path}' \
    --force \
    $ORIGIN \
    --preserve-data \
    || { echo "failed to virt-clone"; exit 1; }

  #{sudo} qemu-img create -f qcow2 -o backing_file=#{original_disk_path} "#{disk_path}"

else

  #{sudo} virt-clone --connect=qemu:///system \
    --name '#{domain_name}' \
    --file '#{disk_path}' \
    --force \
    $ORIGIN \
    || { echo "failed to virt-clone"; exit 1; }

fi

LV_ROOT=$(#{sudo} virt-filesystems -a #{disk_path} --logical-volumes | grep root)
# If using LVM we inject the ssh key this way
if [ -n "$LV_ROOT" ]; then
  if [ -n "#{selinux_enabled}" ]; then
    #{sudo} guestfish --selinux add #{disk_path} : \
      run : \
      mount $LV_ROOT / : \
      sh "/bin/mkdir -p /root/.ssh" : \
      write-append /root/.ssh/authorized_keys "#{ssh_public_key}\n" : \
      sh "/bin/chmod -R 700 /root/.ssh" : \
      sh "load_policy -i" : \
      sh "chcon unconfined_u:object_r:user_home_t:s0 /root/.ssh" : \
      sh "chcon system_u:object_r:ssh_home_t /root/.ssh/authorized_keys"
  else
    #{sudo} guestfish add #{disk_path} : \
      run : \
      mount $LV_ROOT / : \
      sh "/bin/mkdir -p /root/.ssh" : \
      write-append /root/.ssh/authorized_keys "#{ssh_public_key}\n" : \
      sh "/bin/chmod -R 700 /root/.ssh"
  fi
fi

#{sudo} virsh --connect=qemu:///system setmaxmem #{domain_name} #{instance_memory}
#{sudo} virsh --connect=qemu:///system start #{domain_name}
#{sudo} virsh --connect=qemu:///system setmem #{domain_name} #{instance_memory}

    }
    retval=$?
    if not retval.success? 
      puts out
      raise KytoonException, "Failed to create instance #{inst_name}."
    end

    # lookup server IP here... 
    mac_addr = nil
    network_name = nil
    dom_xml = %x{#{sudo} virsh --connect=qemu:///system dumpxml #{domain_name}}
    dom = REXML::Document.new(dom_xml)
    REXML::XPath.each(dom, "//interface/mac") do |interface_xml|
      mac_addr = interface_xml.attributes['address']
    end
    raise KytoonException, "Failed to lookup mac address for #{inst_name}" if mac_addr.nil?
    REXML::XPath.each(dom, "//interface/source") do |interface_xml|
      network_name = interface_xml.attributes['network']
    end
    raise KytoonException, "Failed to lookup network name for #{inst_name}" if network_name.nil?

    instance_ip = %x{grep -i #{mac_addr} /var/lib/libvirt/dnsmasq/#{network_name}.leases | cut -d " " -f 3}.chomp
    count = 0
    until not instance_ip.empty? do
      instance_ip = %x{grep -i #{mac_addr} /var/lib/libvirt/dnsmasq/#{network_name}.leases | cut -d " " -f 3}.chomp
      sleep 1
      count += 1
      if count >= 60 then
          raise KytoonException, "Failed to lookup ip address for #{inst_name}"
      end
    end
    return instance_ip

  end

  def self.cleanup_instances(group_id, inst_name, disk_path, sudo)
    domain_name="#{group_id}_#{inst_name}"
    out = %x{
if [ -n "$DEBUG" ]; then
set -x
fi
if #{sudo} virsh --connect=qemu:///system dumpxml #{domain_name} &> /dev/null; then
  #{sudo} virsh --connect=qemu:///system destroy "#{domain_name}" &> /dev/null
  #{sudo} virsh --connect=qemu:///system undefine "#{domain_name}"
fi
# If we used --preserve-data there will be no volume... ignore it
#{sudo} virsh --connect=qemu:///system vol-delete --pool default "#{group_id}_#{inst_name}.img" &> /dev/null
if [ -f "#{disk_path}" ]; then
  #{sudo} rm -f "#{disk_path}"
fi
    }
    puts out
    retval=$?
    if not retval.success? 
      puts out
      raise KytoonException, "Failed to cleanup instances."
    end
  end

end

end

end

end
