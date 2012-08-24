require 'kytoon/providers/cloud_servers_vpc/connection'
require 'kytoon/providers/cloud_servers_vpc/client'
require 'kytoon/providers/cloud_servers_vpc/server'
require 'kytoon/providers/cloud_servers_vpc/server_group'
require 'kytoon/providers/cloud_servers_vpc/ssh_public_key'
require 'kytoon/providers/cloud_servers_vpc/vpn_network_interface'
require 'kytoon/util'

Kytoon::Util.check_config_param('cloud_servers_vpc_url')
Kytoon::Util.check_config_param('cloud_servers_vpc_username')
Kytoon::Util.check_config_param('cloud_servers_vpc_password')
