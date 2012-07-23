module Kytoon

module Providers

module CloudServersVPC

class Server

  attr_accessor :id
  attr_accessor :name
  attr_accessor :description
  attr_accessor :external_ip_addr
  attr_accessor :internal_ip_addr
  attr_accessor :cloud_server_id_number
  attr_accessor :flavor_id
  attr_accessor :image_id
  attr_accessor :server_group_id
  attr_accessor :openvpn_server
  attr_accessor :retry_count
  attr_accessor :error_message
  attr_accessor :status
  attr_accessor :admin_password

  def initialize(options={})
    @id=options[:id].to_i
    @name=options[:name]
    @description=options[:description] or @description=@name
    @external_ip_addr=options[:external_ip_addr]
    @internal_ip_addr=options[:internal_ip_addr]
    @cloud_server_id_number=options[:cloud_server_id_number]
    @flavor_id=options[:flavor_id]
    @image_id=options[:image_id]
    @admin_password=options[:admin_password]
    @server_group_id=options[:server_group_id].to_i
    @openvpn_server = [true, "true"].include?(options[:openvpn_server])
    @retry_count=options[:retry_count].to_i or 0
    @error_message=options[:error_message]
    @status=options[:status]
    end

  def openvpn_server?
    return @openvpn_server
  end

  def to_xml

    xml = Builder::XmlMarkup.new
    xml.tag! "server" do |server|
      server.id(@id)
      server.name(@name)
      server.description(@description)
      server.status(@status) if @status
      server.tag! "external-ip-addr", @external_ip_addr if @external_ip_addr
      server.tag! "internal-ip-addr", @internal_ip_addr if @internal_ip_addr
      server.tag! "cloud-server-id-number", @cloud_server_id_number if @cloud_server_id_number
      server.tag! "flavor-id", @flavor_id
      server.tag! "image-id", @image_id
      server.tag! "admin-password", @admin_password
      server.tag! "server-group-id", @server_group_id
      server.tag! "openvpn-server", "true" if openvpn_server?
      server.tag! "error-message", @error_message if @error_message
    end
    xml.target!

  end

  def self.from_xml(xml)

    server=nil
        dom = REXML::Document.new(xml)
        REXML::XPath.each(dom, "/*") do |sg_xml|

      server=Server.new(
        :id => XMLUtil.element_text(sg_xml, "id").to_i,
        :name => XMLUtil.element_text(sg_xml, "name"),
        :flavor_id => XMLUtil.element_text(sg_xml, "flavor-id"),
        :image_id => XMLUtil.element_text(sg_xml, "image-id"),
        :admin_password => XMLUtil.element_text(sg_xml, "admin-password"),
        :description => XMLUtil.element_text(sg_xml, "description"),
        :cloud_server_id_number => XMLUtil.element_text(sg_xml, "cloud-server-id-number"),
        :description => XMLUtil.element_text(sg_xml, "description"),
        :external_ip_addr => XMLUtil.element_text(sg_xml, "external-ip-addr"),
        :internal_ip_addr => XMLUtil.element_text(sg_xml, "internal-ip-addr"),
        :server_group_id => XMLUtil.element_text(sg_xml, "server-group-id"),
        :openvpn_server => XMLUtil.element_text(sg_xml, "openvpn_server"),
        :retry_count => XMLUtil.element_text(sg_xml, "retry-count"),
        :error_message => XMLUtil.element_text(sg_xml, "error-message"),
        :status => XMLUtil.element_text(sg_xml, "status")
      )
    end

    server

  end

  def rebuild

    raise "Error: Rebuilding the OpenVPN server is not supported at this time." if openvpn_server?

    Connection.post("/servers/#{@id}/rebuild", {})

  end

    def delete
        Connection.delete("/servers/#{@id}.xml")
    end

  def self.create(server)

    xml=Connection.post("/servers.xml", server.to_xml)
    server=Server.from_xml(xml)

  end

end

end

end

end
