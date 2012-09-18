module Kytoon

class ServerGroup

  @@group_class = nil

  # called to init the configured group class we will use
  def self.init(group_type=nil)
    return if not @@group_class.nil?
    configs = Util.load_configs
    group_type = configs['group_type'] if group_type.nil?
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
        raise ConfigException, "Invalid 'group_type' specified."
    end
  end

  def self.index(options={})
    self.init
    server_groups = @@group_class.index(options)
    if server_groups.size > 0
      puts "Server groups:"
      server_groups.sort { |a,b| b.id <=> a.id }.each do |sg|
        gw=sg.gateway_ip.nil? ? "" : " (#{sg.gateway_ip})"
        puts "\t :id => #{sg.id}, :name => #{sg.name} #{gw}"
      end
    else
      puts "No server groups."
    end
  end

  def self.create(config_file)
    self.init
    if config_file.nil? then
      config_file = @@group_class::CONFIG_FILE
    end
    if not File.exists?(config_file) then
      raise ConfigException, "Please specify a valid GROUP_CONFIG."
    end
    sg = @@group_class.from_json(IO.read(config_file))
    @@group_class.create(sg)
  end

  def self.get(id=nil)
    self.init
    @@group_class.get(:id => id)
  end

  def self.delete(id=nil)
    self.init
    sg = @@group_class.get(:id => id)
    sg.delete
  end

end

end
