module Kytoon

module Providers

module CloudServersVPC

class Client

  @@data_dir=File.join(KYTOON_PROJECT, "tmp", "clients")

  def self.data_dir
    @@data_dir
  end

  def self.data_dir=(dir)
    @@data_dir=dir
  end

  attr_accessor :id
  attr_accessor :name
  attr_accessor :description
  attr_accessor :status
  attr_accessor :server_group_id
  attr_accessor :cache_file

  def initialize(options={})
    @id=options[:id].to_i
    @name=options[:name]
    @description=options[:description]
    if options[:status]
      @status=options[:status]
    else
      @status = "Pending"
    end
    @status=options[:status] or @status = "Pending"
    @server_group_id=options[:server_group_id]
    if options[:cache_file] then
      @cache_file=options[:cache_file]
    else
      @cache_file=options[:server_group_id]
    end
    @vpn_network_interfaces=[]
  end

  def vpn_network_interfaces
    @vpn_network_interfaces
  end

    def cache_to_disk
        FileUtils.mkdir_p(@@data_dir)
        File.open(File.join(@@data_dir, "#{@cache_file}.xml"), 'w') do |f|
            f.chmod(0600)
            f.write(self.to_xml)
        end
    end

  def delete
    client_xml_file=File.join(@@data_dir, "#{@cache_file}.xml")
        if File.exists?(client_xml_file) then
            File.delete(client_xml_file)
        end
  end

  def self.from_xml(xml)
    client=nil
    dom = REXML::Document.new(xml)
    REXML::XPath.each(dom, "/client") do |cxml|

      client=Client.new(
        :id => XMLUtil.element_text(cxml,"id").to_i,
        :name => XMLUtil.element_text(cxml, "name"),
        :description => XMLUtil.element_text(cxml,"description"),
        :status => XMLUtil.element_text(cxml,"status"),
        :server_group_id => XMLUtil.element_text(cxml, "server-group-id").to_i
      )
      REXML::XPath.each(dom, "//vpn-network-interface") do |vni|
        vni = VpnNetworkInterface.new(
          :id => XMLUtil.element_text(vni, "id"),
          :vpn_ip_addr => XMLUtil.element_text(vni, "vpn-ip-addr"),
          :ptp_ip_addr => XMLUtil.element_text(vni, "ptp-ip-addr"),
          :client_key => XMLUtil.element_text(vni, "client-key"),
          :client_cert => XMLUtil.element_text(vni, "client-cert"),
          :ca_cert => XMLUtil.element_text(vni, "ca-cert")
        )
        client.vpn_network_interfaces << vni
      end
    end
    client
  end 

    def to_xml

        xml = Builder::XmlMarkup.new
        xml.tag! "client" do |sg|
            sg.id(@id)
            sg.name(@name)
            sg.description(@description)
            sg.status(@status)
            sg.tag! "server-group-id", @server_group_id
            sg.tag! "vpn-network-interfaces", {"type" => "array"} do |interfaces|
        @vpn_network_interfaces.each do |vni|
          interfaces.tag! "vpn-network-interface" do |xml_vni|
            xml_vni.id(vni.id)
            xml_vni.tag! "vpn-ip-addr", vni.vpn_ip_addr
            xml_vni.tag! "ptp-ip-addr", vni.ptp_ip_addr
            xml_vni.tag! "client-key", vni.client_key
            xml_vni.tag! "client-cert", vni.client_cert
            xml_vni.tag! "ca-cert", vni.ca_cert
          end  
        end
      end

    end
        xml.target!

  end


    # Poll the server group until it is online.
    # :timeout - max number of seconds to wait before raising an exception.
    #            Defaults to 1500
    def poll_until_online(options={})

        timeout=options[:timeout] or timeout = ENV['VPN_CLIENT_TIMEOUT']
        if timeout.nil? or timeout.empty? then
            timeout=300 # defaults to 5 minutes
        end 

    online = false
    count=0
    until online or (count*5) >= timeout.to_i do
      count+=1
      begin
        client=Client.get(:id => @id, :source => "remote")

        if client.status == "Online" then
          online = true
        else
          yield client if block_given?
          sleep 5
        end
      rescue EOFError
      end
    end
    if (count*20) >= timeout.to_i then
      raise "Timeout waiting for client to come online."
    end

  end

  def self.create(server_group, client_name, cache_to_disk=true)

    xml = Builder::XmlMarkup.new
    xml.client do |client|
      client.name(client_name)
      client.description("Toolkit Client: #{client_name}")
      client.tag! "server-group-id", server_group.id
    end

    xml=Connection.post("/clients.xml", xml.target!)
    client=Client.from_xml(xml)
    client.cache_to_disk if cache_to_disk
    client

  end

    # Get a client. The following options are available:
    #
    # :id - The ID of the client to get.
    # :source - valid options are 'remote' and 'cache'
    #
  def self.get(options = {})

        source = options[:source] or source = "remote"

        if source == "remote" then
      id=options[:id] or raise "Please specify a Client ID."
      xml=Connection.get("/clients/#{id}.xml")
      Client.from_xml(xml)
    elsif source == "cache" then
      id=options[:id] or id = ENV['GROUP_ID']
      client_xml_file=File.join(@@data_dir, "#{id}.xml")
      raise "No client files exist." if not File.exists?(client_xml_file)
      Client.from_xml(IO.read(client_xml_file))
    else
      raise "Invalid get :source specified."
    end

  end

end

end

end

end
