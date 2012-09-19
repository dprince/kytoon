include Kytoon

namespace :kytoon do
  TMP_SG=File.join(KYTOON_PROJECT, 'tmp', 'server_groups')

  directory TMP_SG

  task :init => [TMP_SG] do
      ServerGroup.init(ENV['GROUP_TYPE'])
  end

  desc "Create a new group of servers"
  task :create => 'kytoon:init' do
    sg = ServerGroup.create(ENV['GROUP_CONFIG'])
    puts "Server group ID #{sg.id} created."
  end

  desc "List existing server groups."
  task :list => 'kytoon:init' do
    ServerGroup.index(:source => "cache")
  end

  desc "Print information for a server group"
  task :show => 'kytoon:init' do
    sg = ServerGroup.get(ENV['GROUP_ID'])
    sg.pretty_print
  end

  desc "Delete a server group"
  task :delete => 'kytoon:init' do

    sg = ServerGroup.get(ENV['GROUP_ID'])
    puts "Deleting server group ID: #{sg.id}."
    sg.delete
    SshUtil.remove_known_hosts_ip(sg.gateway_ip)

  end

  desc "Print the gateway IP address"
  task :ip => 'kytoon:init' do
    group = ServerGroup.get(ENV['GROUP_ID'])
    puts group.gateway_ip
  end

  desc "SSH into the most recently created server group."
  task :ssh => 'kytoon:init' do

    sg=ServerGroup.get(ENV['GROUP_ID'])
    args=ARGV[1, ARGV.length].join(" ")
    if (ARGV[1] and ARGV[1] =~ /^GROUP_.*/) and (ARGV[2] and ARGV[2] =~ /^GROUP_.*/)
      args=ARGV[3, ARGV.length].join(" ")
    elsif ARGV[1] and ARGV[1] =~ /^GROUP_.*/
      args=ARGV[2, ARGV.length].join(" ")
    end
    exec("ssh -o \"StrictHostKeyChecking no\" root@#{sg.gateway_ip} #{args}")
  end

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
  puts "\t- Create a new server group with default config file"
  puts "\t  (config/server_group.json)."
  puts ""
  puts "\t$ rake kytoon:create"

  puts ""
  puts "\t- List your currently running server groups."
  puts ""
  puts "\t$ rake kytoon:list"

  puts ""
  puts "\t- SSH into the current (most recently created) server group."
  puts ""
  puts "\t$ rake ssh"

  puts ""
  puts "\t- SSH into a server group with an ID of 3."
  puts ""
  puts "\t$ rake ssh GROUP_ID=3"

  puts ""
  puts "\t- Delete the server group with an ID of 3."
  puts ""
  puts "\t$ rake kytoon:delete GROUP_ID=3"

end

task :default => 'usage'
