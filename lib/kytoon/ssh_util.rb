module Kytoon

module SshUtil

  def self.remove_known_hosts_ip(ip, known_hosts_file=File.join(ENV['HOME'], ".ssh", "known_hosts"))

    return if ip.nil? or ip.empty?
    return if not FileTest.exist?(known_hosts_file)

    existing=IO.read(known_hosts_file)
    File.open(known_hosts_file, 'w') do |file|
      existing.each_line do |line|
        if not line =~ Regexp.new("^#{ip}.*$") then
            file.write(line)
        end
      end
    end

  end

end

end
