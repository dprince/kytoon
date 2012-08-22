require 'kytoon/providers/cloud_servers_vpc'
require 'kytoon/providers/libvirt'
require 'kytoon/providers/xenserver'

class ServerGroup

  @@group_class = nil

  # called to init the configured group class we will use
  def self.init
    return if not @@group_class.nil?
    configs = Util.load_configs
    group_type = ENV['GROUP_TYPE'] || configs['group_type']
    if group_type == "cloud_server_vpc" then
        @@group_class = Kytoon::Providers::CloudServersVPC::ServerGroup
    elsif group_type == "xenserver" then
        @@group_class = Kytoon::Providers::Xenserver::ServerGroup
    elsif group_type == "libvirt" then
        @@group_class = Kytoon::Providers::Libvirt::ServerGroup
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
