include Kytoon

namespace :group do
  TMP_SG=File.join(KYTOON_PROJECT, 'tmp', 'server_groups')

  directory TMP_SG

  task :init => [TMP_SG] do
      ServerGroup.init
    end

  desc "Create a new group of cloud servers"
  task :create => [ "init" ] do
    sg = ServerGroup.create
    puts "Server group ID #{sg.id} created."
  end

  desc "List existing cloud server groups."
  task :list => "init" do

    server_groups=nil
    server_groups=ServerGroup.index(:source => "cache")
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

  desc "Print information for a cloud server group"
  task :show => [ "init" ] do
    sg = ServerGroup.get
    sg.pretty_print
  end

  desc "Delete a cloud server group"
  task :delete => ["init"] do

    sg = ServerGroup.get
    puts "Deleting cloud server group ID: #{sg.id}."
    sg.delete
    SshUtil.remove_known_hosts_ip(sg.gateway_ip)

  end

  desc "Print the VPN gateway IP address"
  task :gateway_ip do
    group = ServerGroup.get
    puts group.gateway_ip
  end

end

desc "SSH into the most recently created VPN gateway server."
task :ssh => 'group:init' do

  sg=ServerGroup.get
  args=ARGV[1, ARGV.length].join(" ")
  if (ARGV[1] and ARGV[1] =~ /^GROUP_.*/) and (ARGV[2] and ARGV[2] =~ /^GROUP_.*/)
    args=ARGV[3, ARGV.length].join(" ")
  elsif ARGV[1] and ARGV[1] =~ /^GROUP_.*/
    args=ARGV[2, ARGV.length].join(" ")
  end
  exec("ssh -o \"StrictHostKeyChecking no\" root@#{sg.gateway_ip} #{args}")
end

desc "Print help and usage information"
task :usage do

  puts ""
  puts "Kytoon Toolkit Version: #{Kytoon::Version::VERSION}"
  puts ""
  puts "The following tasks are available:"

  puts %x{cd #{KYTOON_PROJECT} && rake -T}
  puts "----"
  puts "Example commands:"
  puts ""
  puts "\t- Create a new server group."
  puts ""
  puts "\t\t$ rake group:create"

  puts ""
  puts "\t- List your currently running server groups."
  puts ""
  puts "\t\t$ rake group:list"

  puts ""
  puts "\t- List all remote groups using a common Cloud Servers VPC account."
  puts ""
  puts "\t\t$ rake group:list"

  puts ""
  puts "\t- SSH into the current (most recently created) server group."
  puts ""
  puts "\t\t$ rake ssh"

  puts ""
  puts "\t- SSH into a server group with an ID of 3."
  puts ""
  puts "\t\t$ rake ssh GROUP_ID=3"

  puts ""
  puts "\t- Delete the server group with an ID of 3."
  puts ""
  puts "\t\t$ rake group:delete GROUP_ID=3"

end

task :default => 'usage'
