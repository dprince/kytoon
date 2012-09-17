class ServerGroup

  @@group_class = nil

  # called to init the configured group class we will use
  def self.init
    return if not @@group_class.nil?
    configs = Util.load_configs
    group_type = ENV['GROUP_TYPE'] || configs['group_type']
    if group_type == "openstack" then
        require 'kytoon/providers/openstack'
        @@group_class = Kytoon::Providers::Openstack::ServerGroup
    elsif group_type == "xenserver" then
        require 'kytoon/providers/xenserver'
        @@group_class = Kytoon::Providers::Xenserver::ServerGroup
    elsif group_type == "libvirt" then
        require 'kytoon/providers/libvirt'
        @@group_class = Kytoon::Providers::Libvirt::ServerGroup
    elsif group_type == "cloud_server_vpc" or group_type == "cloud_servers_vpc" then
        require 'kytoon/providers/cloud_servers_vpc'
        @@group_class = Kytoon::Providers::CloudServersVPC::ServerGroup
    else
        raise "Invalid 'group_type' specified in config file."
    end
  end

  def self.index(options)
    self.init
    @@group_class.index(options)
  end

  def self.create
    self.init
    json_config_file=ENV['SERVER_GROUP_JSON']
    if json_config_file.nil? then
      json_config_file = @@group_class::CONFIG_FILE
    end
    sg = @@group_class.from_json(IO.read(json_config_file))
    @@group_class.create(sg)
  end

  def self.get
    self.init
    id = ENV['GROUP_ID']
    @@group_class.get(:id => id)
  end

  def self.delete
    self.init
    id = ENV['GROUP_ID']
    sg = @@group_class.get(:id => id)
    sg.delete
  end

end
