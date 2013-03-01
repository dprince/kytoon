require 'thor'

module Kytoon

class ThorTasks < Thor

  desc "create", "Create a new server group."
  method_options :group_type => :string
  method_options :group_config => :string


  def create(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.create(options[:group_config])
      puts "Server group ID #{sg.id} created."
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end


  desc "list", "List existing server groups."
  method_options :group_type => :string
  def list(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      ServerGroup.index()
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "show", "Print information for a server group."
  method_options :group_id => :string
  method_options :group_type => :string
  def show(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.get(options[:group_id])
      sg.pretty_print
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "delete", "Delete a server group."
  method_options :group_id => :string
  method_options :group_type => :string
  def delete(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.get(options[:group_id])
      sg.delete
      SshUtil.remove_known_hosts_ip(sg.gateway_ip)
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "ip", "Print the IP address of the gateway server"
  method_options :group_id => :string
  method_options :group_type => :string
  def ip(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.get(options[:group_id])
      puts sg.gateway_ip
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "ssh", "SSH into a group."
  method_options :group_id => :string
  method_options :group_type => :string
  def ssh(*)
    begin
      ServerGroup.init(options[:group_type])
      args=ARGV[1, ARGV.length].join(" ")
      sg = ServerGroup.get(options[:group_id])
      if (ARGV[1] and ARGV[1] =~ /^--group_id.*/) and (ARGV[2] and ARGV[2] =~ /^--group_id.*/)
        args=ARGV[3, ARGV.length].join(" ")
      elsif ARGV[1] and ARGV[1] =~ /^--group_id.*/
        args=ARGV[2, ARGV.length].join(" ")
      end
      exec("ssh -o \"StrictHostKeyChecking no\" root@#{sg.gateway_ip} #{args}")
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

end

end
