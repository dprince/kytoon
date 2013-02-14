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
      @@configs=configs
    else
      raise ConfigException, "Failed to load kytoon config file. Please configure /etc/kytoon.conf or create a .kytoon.conf config file in your HOME directory."
    end

    @@configs

  end

  def self.public_key_path

    ssh_dir=File.join(ENV['HOME'], ".ssh")
    if File.exists?(File.join(ssh_dir, "id_rsa.pub"))
      File.join(ssh_dir, "id_rsa.pub")
    elsif File.exists?(File.join(ssh_dir, "id_dsa.pub"))
      File.join(ssh_dir, "id_dsa.pub")
    else
      raise ConfigException, "Failed to load SSH key. Please run 'ssh-keygen'."
    end

  end

  def self.load_public_key

    pubkey=IO.read(self.public_key_path)
    pubkey.chomp

  end

  def self.check_config_param(key)
    configs = load_configs
    if not configs or configs[key].nil? or configs[key].to_s.empty? then
      raise ConfigException, "Please specify '#{key.to_s}' in your kytoon config file."
    end
  end

  def self.remote_exec(script_text, gateway_ip, retry_attempts=0, retry_sleep=5)
    if gateway_ip.nil?
      sg=ServerGroup.get
      gateway_ip=sg.gateway_ip
    end

    retval=nil
    out=nil
    (retry_attempts+1).times do |count|
      sleep retry_sleep if count > 1
      out=%x{
ssh #{SSH_OPTS} root@#{gateway_ip} bash <<-"REMOTE_EXEC_EOF"
#{script_text}
REMOTE_EXEC_EOF
      }
      retval=$?
      break if retval.success?
    end
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

  # Generate an ssh keypair using the specified base path
  def self.generate_ssh_keypair(ssh_key_basepath)
    FileUtils.mkdir_p(File.dirname(ssh_key_basepath))
    %x{ssh-keygen -N '' -f #{ssh_key_basepath} -t rsa -q}
  end

end

end
