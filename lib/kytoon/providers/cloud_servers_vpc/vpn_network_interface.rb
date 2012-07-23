module Kytoon

module Providers

module CloudServersVPC

class VpnNetworkInterface

  attr_accessor :id
  attr_accessor :vpn_ip_addr
  attr_accessor :ptp_ip_addr
  attr_accessor :client_key
  attr_accessor :client_cert
  attr_accessor :ca_cert

  def initialize(options={})

    @id=options[:id].to_i
    @vpn_ip_addr=options[:vpn_ip_addr]
    @ptp_ip_addr=options[:ptp_ip_addr]
    @client_key=options[:client_key]
    @client_cert=options[:client_cert]
    @ca_cert=options[:ca_cert]

  end

end

end

end

end
