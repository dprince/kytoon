require 'kytoon/providers/openstack/server_group'

Kytoon::Util.check_config_param('openstack_url')
Kytoon::Util.check_config_param('openstack_username')
Kytoon::Util.check_config_param('openstack_password')
