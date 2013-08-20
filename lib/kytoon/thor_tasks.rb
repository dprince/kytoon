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
  method_options :remote => :boolean, :default => false
  def list(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      ServerGroup.index({:remote => options[:remote]})
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "show", "Print information for a server group."
  method_options :group_id => :string
  method_options :group_type => :string
  method_options :remote => :boolean, :default => false
  def show(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.get(options[:group_id], {:remote => options[:remote]})
      sg.pretty_print
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "delete", "Delete a server group."
  method_options :group_id => :string
  method_options :group_type => :string
  method_options :remote => :boolean, :default => false
  def delete(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.get(options[:group_id], {:remote => options[:remote]})
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
  method_options :remote => :boolean, :default => false
  def ip(options=(options or {}))
    begin
      ServerGroup.init(options[:group_type])
      sg = ServerGroup.get(options[:group_id], {:remote => options[:remote]})
      puts sg.gateway_ip
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

  desc "ssh", "SSH into a group."
  method_options :group_id => :string
  method_options :group_type => :string
  method_options :remote => :boolean, :default => false
  def ssh(*)
    begin
      ServerGroup.init(options[:group_type])
      args=ARGV[1, ARGV.length].join(" ")
      sg = ServerGroup.get(options[:group_id], {:remote => options[:remote]})
      arg_count = 1
      arg_count +=1 if args =~ /--group_type/
      arg_count +=1 if args =~ /--group_id/
      arg_count +=1 if args =~ /--remote/
      args=ARGV[arg_count, ARGV.length].join(" ")
      exec("ssh -o \"StrictHostKeyChecking no\" root@#{sg.gateway_ip} #{args}")
    rescue KytoonException => ke
      puts ke.message
      exit 1
    end
  end

end

end
