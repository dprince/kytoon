require 'test/unit'
require 'rubygems'
require 'mocha'
KYTOON_PROJECT = "#{File.dirname(__FILE__)}" unless defined?(KYTOON_PROJECT)

$:.unshift File.dirname(__FILE__) + '/../lib'
require 'kytoon'

require 'tempfile'
require 'fileutils'

class TmpDir

  def self.new_tmp_dir(prefix="kytoon")

    tmp_file=Tempfile.new prefix
    path=tmp_file.path
    tmp_file.close(true)
    FileUtils.mkdir_p path
    return path

  end

end

SERVER_GROUP_XML = %{
<?xml version="1.0" encoding="UTF-8"?>
<server-group>
  <created-at type="datetime">2010-10-15T15:15:58-04:00</created-at>
  <description>test description</description>
  <domain-name>mydomain.net</domain-name>
  <historical type="boolean">false</historical>
  <id type="integer">1759</id>
  <last-used-ip-address>172.19.0.2</last-used-ip-address>
  <name>test</name>
  <owner-name>dan.prince</owner-name>
  <updated-at type="datetime">2010-10-15T15:15:58-04:00</updated-at>
  <user-id type="integer">3</user-id>
  <servers type="array">
    <server>
      <account-id type="integer">3</account-id>
      <cloud-server-id-number type="integer">1</cloud-server-id-number>
      <created-at type="datetime">2010-10-15T15:15:58-04:00</created-at>
      <description>login1</description>
      <error-message nil="true"></error-message>
      <external-ip-addr>184.106.205.120</external-ip-addr>
      <flavor-id type="integer">4</flavor-id>
      <historical type="boolean">false</historical>
      <id type="integer">5513</id>
      <image-id type="integer">14</image-id>
      <internal-ip-addr>10.179.107.203</internal-ip-addr>
      <name>login1</name>
      <gateway type="boolean">true</gateway>
      <retry-count type="integer">0</retry-count>
      <server-group-id type="integer">1759</server-group-id>
      <status>Online</status>
      <updated-at type="datetime">2010-10-15T15:18:22-04:00</updated-at>
    </server>
    <server>
      <account-id type="integer">3</account-id>
      <cloud-server-id-number type="integer">2</cloud-server-id-number>
      <created-at type="datetime">2010-10-15T15:15:58-04:00</created-at>
      <description>test1</description>
      <error-message nil="true"></error-message>
      <external-ip-addr>184.106.205.121</external-ip-addr>
      <flavor-id type="integer">49</flavor-id>
      <historical type="boolean">false</historical>
      <id type="integer">5513</id>
      <image-id type="integer">49</image-id>
      <internal-ip-addr>10.179.107.204</internal-ip-addr>
      <name>test1</name>
      <gateway type="boolean">false</gateway>
      <retry-count type="integer">0</retry-count>
      <server-group-id type="integer">1759</server-group-id>
      <status>Online</status>
      <updated-at type="datetime">2010-10-15T15:18:22-04:00</updated-at>
    </server>
  </servers>
</server-group>
}

SERVER_XML = %{

<linux-server> 
  <cloud-server-id-number type="integer">888</cloud-server-id-number> 
  <created-at type="datetime">2010-07-29T10:27:33-04:00</created-at> 
  <description>blah</description> 
  <error-message nil="true"></error-message> 
  <external-ip-addr>123.100.100.100</external-ip-addr> 
  <flavor-id type="integer">3</flavor-id> 
  <id type="integer">1234</id> 
  <image-id type="integer">14</image-id> 
  <internal-ip-addr>10.119.225.116</internal-ip-addr> 
  <name>db1</name> 
  <gateway type="boolean">false</gateway> 
  <retry-count type="integer">0</retry-count> 
  <server-group-id type="integer">999</server-group-id> 
  <status>Online</status> 
  <updated-at type="datetime">2010-07-29T11:19:04-04:00</updated-at> 
</linux-server>
}
