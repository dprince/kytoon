require 'json'
require 'kytoon/util'
require 'rexml/document'
require 'rexml/xpath'

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
        'hostname' => server_hash['hostname'],
        'memory' => server_hash['memory'],
        'original' => server_hash['original'],
        'original_xml' => server_hash['original_xml'],
        'create_cow' => server_hash['create_cow'],
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
        sg_hash['servers'] << {'hostname' => server['hostname'], 'memory' => server['memory'], 'gateway' => server['gateway'], 'original' => server['original'], 'original_xml' => server['original_xml'], 'create_cow' => server['create_cow'], 'disk_path' => server['disk_path'], 'ip_address' => server['ip_address']}
    end

    FileUtils.mkdir_p(@@data_dir)
    File.open(File.join(@@data_dir, "#{@id}.json"), 'w') do |f|
      f.chmod(0600)
      f.write(sg_hash.to_json)
    end
  end

  def delete
    servers.each do |server|
      ServerGroup.cleanup_instances(@id, server['hostname'], server['disk_path'])
    end
    out_file=File.join(@@data_dir, "#{@id}.json")
    File.delete(out_file) if File.exists?(out_file)
  end

  def self.create(sg)
    ssh_public_key = Kytoon::Util.load_public_key

    hosts_file_data = "127.0.0.1\tlocalhost localhost.localdomain\n"
    sg.servers.each do |server|

      image_dir=server['image_dir'] || '/var/lib/libvirt/images'
      disk_path=File.join(image_dir, "#{sg.id}_#{server['hostname']}.img")
      server['disk_path'] = disk_path

      instance_ip = create_instance(sg.id, server['hostname'], server['memory'], server['original'], server['original_xml'], disk_path, server['create_cow'], ssh_public_key)
      server['ip_address'] = instance_ip
      hosts_file_data += "#{instance_ip}\t#{server['hostname']}\n"
      sg.cache_to_disk
    end

    puts "Copying hosts files..."
    #now that we have IP info copy hosts files into the servers
    sg.servers.each do |server|
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
          raise "Failed to copy host file to instance #{server['hostname']}."
        end
      end
    end

    sg
  end

  def self.get(options={})
    id = options[:id]
    if id.nil? then
      group=ServerGroup.most_recent
      raise "No server group files exist." if group.nil?
      id=group.id
    end

    out_file=File.join(@@data_dir, "#{id}.json")
    raise "No server group files exist." if not File.exists?(out_file)
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
    raise "Unable to find disk path for instance."
  end

  def self.create_instance(group_id, inst_name, memory_gigs, original, original_xml, disk_path, create_cow, ssh_public_key)

    puts "Creating instance: #{inst_name}"
    instance_memory = (KIB_PER_GIG * memory_gigs.to_f).to_i
    original_disk_path = source_disk_filename(original, original_xml) #cow only
    domain_name="#{group_id}_#{inst_name}"

    out = %x{
if [ -n "$DEBUG" ]; then
set -x
fi
export VIRSH_DEFAULT_CONNECT_URI="qemu:///system"
if [ -n "#{original_xml}" ]; then
  ORIGIN="--original-xml #{original_xml}"
elif [ -n "#{original}" ]; then
  ORIGIN="--original #{original}"
else
    { echo "Please specify 'original' or 'original_xml'."; exit 1; }
fi

if [ -n "#{create_cow}" ]; then

  virt-clone --connect="$VIRSH_DEFAULT_CONNECT_URI" \
    --name '#{domain_name}' \
    --file '#{disk_path}' \
    --force \
    $ORIGIN \
    --preserve-data \
    || { echo "failed to virt-clone"; exit 1; }

  qemu-img create -f qcow2 -o backing_file=#{original_disk_path} "#{disk_path}"

else

  virt-clone --connect="$VIRSH_DEFAULT_CONNECT_URI" \
    --name '#{domain_name}' \
    --file '#{disk_path}' \
    --force \
    $ORIGIN \
    || { echo "failed to virt-clone"; exit 1; }

fi

LV_ROOT=$(virt-filesystems -a #{disk_path} --logical-volumes | grep root)
# If using LVM we inject the ssh key this way
if [ -n "$LV_ROOT" ]; then
  guestfish --selinux add #{disk_path} : \
    run : \
    mount $LV_ROOT / : \
    sh "/bin/mkdir -p /root/.ssh" : \
    write-append /root/.ssh/authorized_keys "#{ssh_public_key}" : \
    sh "/bin/chmod -R 700 /root/.ssh"
fi

virsh setmaxmem #{domain_name} #{instance_memory}
virsh start #{domain_name}
virsh setmem #{domain_name} #{instance_memory}

    }
    retval=$?
    if not retval.success? 
      puts out
      raise "Failed to create instance #{inst_name}."
    end

    # lookup server IP here... 
    mac_addr = nil
    dom_xml = %x{virsh --connect=qemu:///system dumpxml #{domain_name}}
    dom = REXML::Document.new(dom_xml)
    REXML::XPath.each(dom, "//interface/mac") do |interface_xml|
      mac_addr = interface_xml.attributes['address']
    end
    raise "Failed to lookup mac address for #{inst_name}" if mac_addr.nil?

    instance_ip = %x{grep -i #{mac_addr} /var/lib/libvirt/dnsmasq/default.leases | cut -d " " -f 3}.chomp
    count = 0
    until not instance_ip.empty? do
      instance_ip = %x{grep -i #{mac_addr} /var/lib/libvirt/dnsmasq/default.leases | cut -d " " -f 3}.chomp
      sleep 1
      count += 1
      if count >= 60 then
          raise "Failed to lookup ip address for #{inst_name}"
      end
    end
    return instance_ip

  end

  def self.cleanup_instances(group_id, inst_name, disk_path)
    domain_name="#{group_id}_#{inst_name}"
    out = %x{
if [ -n "$DEBUG" ]; then
set -x
fi
export VIRSH_DEFAULT_CONNECT_URI="qemu:///system"
if virsh dumpxml #{domain_name} &> /dev/null; then
  virsh destroy "#{domain_name}" &> /dev/null
  virsh undefine "#{domain_name}"
fi
# If we used --preserve-data there will be no volume... ignore it
virsh vol-delete --pool default "#{group_id}_#{inst_name}.img" &> /dev/null
if [ -f "#{disk_path}" ]; then
  rm -f "#{disk_path}"
fi
    }
    puts out
    retval=$?
    if not retval.success? 
      puts out
      raise "Failed to cleanup instances."
    end
  end

end

end

end

end
