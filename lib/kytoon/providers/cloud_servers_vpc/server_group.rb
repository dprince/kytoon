require 'json'
require 'builder'
require 'fileutils'
require 'rexml/document'
require 'rexml/xpath'

module Kytoon

module Providers

module CloudServersVPC

class ServerGroup

  @@data_dir=File.join(KYTOON_PROJECT, "tmp", "cloud_servers_vpc")

  def self.data_dir
    @@data_dir
  end

  def self.data_dir=(dir)
    @@data_dir=dir
  end

  CONFIG_FILE = KYTOON_PROJECT + File::SEPARATOR + "config" + File::SEPARATOR + "server_group.json"

  attr_accessor :id
  attr_accessor :name
  attr_accessor :description
  attr_accessor :domain_name
  attr_accessor :vpn_device
  attr_accessor :vpn_proto
  attr_accessor :vpn_network
  attr_accessor :vpn_subnet
  attr_accessor :owner_name

  attr_reader :ssh_public_keys

  def initialize(options={})
    @id=options[:id]
    @name=options[:name]
    @description=options[:description]
    @domain_name=options[:domain_name]
    @vpn_device=options[:vpn_device] or @vpn_device="tun"
    @vpn_proto=options[:vpn_proto] or @vpn_proto="tcp"
    @vpn_network=options[:vpn_network] or @vpn_network="172.19.0.0"
    @vpn_subnet=options[:vpn_subnet] or @vpn_subnet="255.255.128.0"
    @owner_name=options[:owner_name] or @owner_name=ENV['USER']

    @servers=[]
    @clients=[]
    @ssh_public_keys=[]
    end

  def server(name)
    @servers.select {|s| s.name == name}[0] if @servers.size > 0
  end

  def servers
    @servers
  end

  def client(name)
    @clients.select {|s| s.name == name}[0] if @clients.size > 0
  end

    def clients
        @clients
    end

  def vpn_gateway_name
    @servers.select {|s| s.openvpn_server? }[0].name if @servers.size > 0
  end

  def gateway_ip
    @servers.select {|s| s.openvpn_server? }[0].external_ip_addr if @servers.size > 0
  end

  def ssh_public_keys
    @ssh_public_keys
  end

  # generate a Server Group XML from server_group.json
  def self.from_json(json)

    json_hash=JSON.parse(json)

    sg=ServerGroup.new(
      :name => json_hash["name"],
      :description => json_hash["description"],
      :domain_name => json_hash["domain_name"],
      :vpn_device => json_hash["vpn_device"],
      :vpn_proto => json_hash["vpn_proto"],
      :vpn_network => json_hash["vpn_network"],
      :vpn_subnet => json_hash["vpn_subnet"]
      )
    json_hash["servers"].each_pair do |server_name, server_config|
      sg.servers << Server.new(
        :name => server_name,
        :description => server_config["description"],
        :flavor_id => server_config["flavor_id"],
        :image_id => server_config["image_id"],
        :openvpn_server => server_config["openvpn_server"]
      )
    end

    # automatically add a key for the current user
    sg.ssh_public_keys << SshPublicKey.new(
      :description => "#{ENV['USER']}'s public key",
      :public_key => Util.load_public_key

    )

    return sg

  end

  def to_xml

    xml = Builder::XmlMarkup.new
    xml.tag! "server-group" do |sg|
      sg.id(@id)
      sg.name(@name)
      sg.description(@description)
      sg.tag! "owner-name", @owner_name
      sg.tag! "domain-name", @domain_name
      sg.tag! "vpn-device", @vpn_device if @vpn_device != "tun"
      sg.tag! "vpn-proto", @vpn_proto if @vpn_proto != "tcp"
      sg.tag! "vpn-network", @vpn_network
      sg.tag! "vpn-subnet", @vpn_subnet
      sg.servers("type" => "array") do |xml_servers|
        self.servers.each do |server|
          xml_servers.server do |xml_server|
            xml_server.id(server.id)
            xml_server.name(server.name)
            xml_server.description(server.description)
            xml_server.tag! "flavor-id", server.flavor_id
            xml_server.tag! "image-id", server.image_id
                        if server.admin_password then
                xml_server.tag! "admin-password", server.admin_password
                        end
            xml_server.tag! "cloud-server-id-number", server.cloud_server_id_number if server.cloud_server_id_number
            xml_server.tag! "status", server.status if server.status
            xml_server.tag! "external-ip-addr", server.external_ip_addr if server.external_ip_addr
            xml_server.tag! "internal-ip-addr", server.internal_ip_addr if server.internal_ip_addr
            xml_server.tag! "error-message", server.error_message if server.error_message
            xml_server.tag! "retry-count", server.retry_count if server.retry_count
            if server.openvpn_server?
              xml_server.tag! "openvpn-server", "true", { "type" => "boolean"}
            end
          end
        end
      end
      sg.tag! "ssh-public-keys", { "type" => "array"} do |xml_ssh_pub_keys|
        self.ssh_public_keys.each do |ssh_public_key|
          xml_ssh_pub_keys.tag! "ssh-public-key" do |xml_ssh_pub_key|
            xml_ssh_pub_key.description ssh_public_key.description
            xml_ssh_pub_key.tag! "public-key", ssh_public_key.public_key
          end
        end
      end
      sg.tag! "clients", { "type" => "array"} do |xml_clients|
        self.clients.each do |client|
          xml_clients.tag! "client" do |xml_client|
            xml_client.id client.id
            xml_client.name client.name
            xml_client.description client.description
            xml_client.status client.status
          end
        end
      end

    end
    xml.target!

  end

  def self.from_xml(xml)

    sg=nil
        dom = REXML::Document.new(xml)
        REXML::XPath.each(dom, "/server-group") do |sg_xml|
      sg=ServerGroup.new(
        :name => XMLUtil.element_text(sg_xml, "name"),
        :id => XMLUtil.element_text(sg_xml, "id").to_i,
        :owner_name => XMLUtil.element_text(sg_xml, "owner-name"),
        :domain_name => XMLUtil.element_text(sg_xml, "domain-name"),
        :description => XMLUtil.element_text(sg_xml, "description"),
        :vpn_device => XMLUtil.element_text(sg_xml, "vpn-device"),
        :vpn_proto => XMLUtil.element_text(sg_xml, "vpn-proto"),
        :vpn_network => XMLUtil.element_text(sg_xml, "vpn-network"),
        :vpn_subnet => XMLUtil.element_text(sg_xml, "vpn-subnet")
      )
      REXML::XPath.each(dom, "//server") do |server_xml|

        server=Server.new(
          :id => XMLUtil.element_text(server_xml, "id").to_i,
          :name => XMLUtil.element_text(server_xml, "name"),
          :cloud_server_id_number => XMLUtil.element_text(server_xml, "cloud-server-id-number"),
          :status => XMLUtil.element_text(server_xml, "status"),
          :external_ip_addr => XMLUtil.element_text(server_xml, "external-ip-addr"),
          :internal_ip_addr => XMLUtil.element_text(server_xml, "internal-ip-addr"),
          :error_message => XMLUtil.element_text(server_xml, "error-message"),
          :image_id => XMLUtil.element_text(server_xml, "image-id"),
          :admin_password => XMLUtil.element_text(server_xml, "admin-password"),
          :flavor_id => XMLUtil.element_text(server_xml, "flavor-id"),
          :retry_count => XMLUtil.element_text(server_xml, "retry-count"),
          :openvpn_server => XMLUtil.element_text(server_xml, "openvpn-server")
        )
        sg.servers << server
      end
      REXML::XPath.each(dom, "//client") do |client_xml|

        client=Client.new(
          :id => XMLUtil.element_text(client_xml, "id").to_i,
          :name => XMLUtil.element_text(client_xml, "name"),
          :description => XMLUtil.element_text(client_xml, "description"),
          :status => XMLUtil.element_text(client_xml, "status")
        )
        sg.clients << client
      end

    end

    sg

  end

  def pretty_print

    puts "Group ID: #{@id}"
    puts "name: #{@name}"
    puts "description: #{@description}"
    puts "domain name: #{@domain_name}"
    puts "VPN gateway IP: #{self.gateway_ip}"
    puts "Servers:"
    servers.each do |server|
      puts "\tname: #{server.name} (id: #{server.id})"
      puts "\tstatus: #{server.status}"
      if server.openvpn_server?
        puts "\tOpenVPN server: #{server.openvpn_server?}"
      end
      if server.error_message then
        puts "\tlast error message: #{server.error_message}"
      end
      puts "\t--"
    end

  end

  def server_names

    names=[]  

    servers.each do |server|
      if block_given? then
        yield server.name
      else
        names << server.name
      end  
    end

    names
    
  end

  def cache_to_disk
    FileUtils.mkdir_p(@@data_dir)
    File.open(File.join(@@data_dir, "#{@id}.xml"), 'w') do |f|
      f.chmod(0600)
      f.write(self.to_xml)
    end
  end

  def delete
    Connection.delete("/server_groups/#{@id}.xml")
    out_file=File.join(@@data_dir, "#{@id}.xml")
    File.delete(out_file) if File.exists?(out_file)
  end

  # Poll the server group until it is online.
  # :timeout - max number of seconds to wait before raising an exception.
  #            Defaults to 1500
  def poll_until_online(options={})

    timeout=options[:timeout] or timeout = ENV['TIMEOUT']
    if timeout.nil? or timeout.empty? then
      timeout=1500 # defaults to 25 minutes
    end  

    online = false
    count=0
    until online or (count*20) >= timeout.to_i do
      count+=1
      begin
        sg=ServerGroup.get(:id => @id, :source => "remote")

        online=true
        sg.servers.each do |server|
          if ["Pending", "Rebuilding"].include?(server.status) then
            online=false
          end
          if server.status == "Failed" then
            raise "Failed to create server group with the following message: #{server.error_message}"
          end
        end
        if not online
          yield sg if block_given?
          sleep 20
        end
      rescue EOFError
      end
    end
    if (count*20) >= timeout.to_i then
      raise "Timeout waiting for server groups to come online."
    end

  end

  def self.create(sg)

    xml=Connection.post("/server_groups.xml", sg.to_xml)
    sg=ServerGroup.from_xml(xml)

    old_group_xml=nil
    vpn_gateway=nil
    sg.poll_until_online do |server_group|
      if old_group_xml != server_group.to_xml then
        old_group_xml = server_group.to_xml
        vpn_gateway = server_group.gateway_ip if server_group.gateway_ip
        if not vpn_gateway.nil? and not vpn_gateway.empty? then
          SshUtil.remove_known_hosts_ip(vpn_gateway)
        end
        server_group.pretty_print
      end
    end
    sg=ServerGroup.get(:id => sg.id, :source => "remote")
    sg.cache_to_disk
    puts "Server group online."
    sg

  end

  # Get a server group. The following options are available:
  #
  # :id - The ID of the server group to get. Defaults to ENV['GROUP_ID']
  # :source - valid options are 'cache' and 'remote'
  def self.get(options={})

    source = options[:source] or source = "cache"
    id = options[:id]
    if id.nil? then
      group = ServerGroup.most_recent
      raise "No recent server group files exist." if group.nil?
      id = group.id
    end

    if source == "remote" then
      xml=Connection.get("/server_groups/#{id}.xml")
      ServerGroup.from_xml(xml)
    elsif source == "cache" then
      out_file = File.join(@@data_dir, "#{id}.xml")
      raise "No server group files exist." if not File.exists?(out_file)
      ServerGroup.from_xml(IO.read(out_file))
    else
      raise "Invalid get :source specified."
    end

  end

  # :source - valid options are 'remote' and 'cache'
  def self.index(options={})

    source = options[:source] or source = "cache"
    server_groups=[]
    Dir[File.join(ServerGroup.data_dir, '*.xml')].each do  |file|
      server_groups << ServerGroup.from_xml(IO.read(file))
    end
    server_groups

  end

  def self.most_recent
    server_groups=[]
    Dir[File.join(@@data_dir, "*.xml")].each do |file|
      server_groups << ServerGroup.from_xml(IO.read(file))
    end
    if server_groups.size > 0 then
      return server_groups.sort { |a,b| b.id <=> a.id }[0]
    else
      nil
    end
  end

end

end

end

end
