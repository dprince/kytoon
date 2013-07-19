module Kytoon

module Providers

module CloudCue

class SshPublicKey

  attr_accessor :id
  attr_accessor :description
  attr_accessor :public_key
  attr_accessor :server_group_id

  def initialize(options={})

    @id=options[:id]
    @description=options[:description]
    @public_key=options[:public_key]
    @server_group_id=options[:server_group_id]

  end

end

end

end

end
