require 'yaml'
require 'socket'
require 'kytoon/server_group'

module Kytoon

module Util

  SSH_OPTS="-o StrictHostKeyChecking=no"

  @@configs=nil

  def self.hostname
    Socket.gethostname
  end

  def self.load_configs

    return @@configs if not @@configs.nil?

    config_file=ENV['KYTOON_CONFIG_FILE']
    if config_file.nil? then

      config_file=ENV['HOME']+File::SEPARATOR+".kytoon.conf"
      if not File.exists?(config_file) then
        config_file="/etc/kytoon.conf"
      end

    end

    if File.exists?(config_file) then
      configs=YAML.load_file(config_file)
      raise_if_nil_or_empty(configs, "cloud_servers_vpc_url")
      raise_if_nil_or_empty(configs, "cloud_servers_vpc_username")
      raise_if_nil_or_empty(configs, "cloud_servers_vpc_password")
      @@configs=configs
    else
      raise "Failed to load kytoon config file. Please configure /etc/kytoon.conf or create a .kytoon.conf config file in your HOME directory."
    end

    @@configs

  end

  def self.load_public_key

    ssh_dir=ENV['HOME']+File::SEPARATOR+".ssh"+File::SEPARATOR
    if File.exists?(ssh_dir+"id_rsa.pub")
      pubkey=IO.read(ssh_dir+"id_rsa.pub")
    elsif File.exists?(ssh_dir+"id_dsa.pub")
      pubkey=IO.read(ssh_dir+"id_dsa.pub")
    else
      raise "Failed to load SSH key. Please create a SSH public key pair in your HOME directory."
    end

    pubkey.chomp

  end

  def self.raise_if_nil_or_empty(options, key)
    if not options or options[key].nil? or options[key].empty? then
      raise "Please specify a valid #{key.to_s} parameter."
    end
  end

  def self.remote_exec(script_text, gateway_ip)
    if gateway_ip.nil?
      sg=ServerGroup.get
      gateway_ip=sg.gateway_ip
    end

    out=%x{
ssh #{SSH_OPTS} root@#{gateway_ip} bash <<-"REMOTE_EXEC_EOF"
#{script_text}
REMOTE_EXEC_EOF
    }
    retval=$?
    if block_given? then
      yield retval.success?, out
    else
      return [retval.success?, out]
    end
  end

  def self.remote_multi_exec(hosts, script_text, gateway_ip)

    if gateway_ip.nil?
      sg=ServerGroup.get
      gateway_ip=sg.gateway_ip
    end

    results = {}
    threads = []

    hosts.each do |host|
      t = Thread.new do
        out=%x{
ssh #{SSH_OPTS} root@#{gateway_ip} bash <<-"REMOTE_EXEC_EOF"
ssh #{host} bash <<-"EOF_HOST"
#{script_text}
EOF_HOST
REMOTE_EXEC_EOF
       }
       retval=$?
      results.store host, [retval.success?, out]
      end
      threads << t
    end

    threads.each {|t| t.join}

    return results

  end

end

end
