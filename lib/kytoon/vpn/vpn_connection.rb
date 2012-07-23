
module Kytoon
module Vpn
class VpnConnection

  CERT_DIR=File.join(ENV['HOME'], '.pki', 'openvpn')

  def initialize(group, client = nil)
    @group = group
    @client = client
  end

  def create_certs
    @ca_cert=get_cfile('ca.crt')
    @client_cert=get_cfile('client.crt')
    @client_key=get_cfile('client.key')

    vpn_interface = @client.vpn_network_interfaces[0]

    FileUtils.mkdir_p(get_cfile)
    File::chmod(0700, File.join(ENV['HOME'], '.pki'))
    File::chmod(0700, CERT_DIR)

    File.open(@ca_cert, 'w') { |f| f.write(vpn_interface.ca_cert) }
    File.open(@client_cert, 'w') { |f| f.write(vpn_interface.client_cert) }
    File.open(@client_key, 'w') do |f|
      f.write(vpn_interface.client_key)
      f.chmod(0600)
    end
      end

  def delete_certs
    FileUtils.rm_rf(get_cfile)
  end

  def get_cfile(file = nil)
    if file
      File.join(CERT_DIR, @group.id.to_s, file)
    else
      File.join(CERT_DIR, @group.id.to_s)
    end
  end

end
end
end
