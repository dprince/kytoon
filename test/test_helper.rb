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
  <vpn-network>172.19.0.0</vpn-network>
  <vpn-subnet>255.255.128.0</vpn-subnet>
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
      <openvpn-server type="boolean">true</openvpn-server>
      <retry-count type="integer">0</retry-count>
      <server-group-id type="integer">1759</server-group-id>
      <status>Online</status>
      <updated-at type="datetime">2010-10-15T15:18:22-04:00</updated-at>
      <vpn-network-interfaces type="array"/>
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
      <openvpn-server type="boolean">false</openvpn-server>
      <retry-count type="integer">0</retry-count>
      <server-group-id type="integer">1759</server-group-id>
      <status>Online</status>
      <updated-at type="datetime">2010-10-15T15:18:22-04:00</updated-at>
      <vpn-network-interfaces type="array"/>
    </server>
  </servers>
</server-group>
}

CLIENT_XML = %{
<client>
  <created-at type="datetime">2011-01-09T19:37:32-05:00</created-at>
  <description>Toolkit Client: local</description>
  <id type="integer">5</id>
  <is-windows type="boolean">false</is-windows>
  <name>local</name>
  <server-group-id type="integer">11</server-group-id>
  <status>Online</status>
  <updated-at type="datetime">2011-01-09T19:37:37-05:00</updated-at>
  <vpn-network-interfaces type="array">
    <vpn-network-interface>
      <ca-cert>-----BEGIN CERTIFICATE-----
MIIDyDCCAzGgAwIBAgIJAORNZNRpPx87MA0GCSqGSIb3DQEBBQUAMIGfMQswCQYD
VQQGEwJVUzELMAkGA1UECBMCVkExEzARBgNVBAcTCkJsYWNrc2J1cmcxEjAQBgNV
BAoTCVJhY2tzcGFjZTEXMBUGA1UECxMOSW5mcmFzdHJ1Y3R1cmUxDjAMBgNVBAMT
BWxvZ2luMQ4wDAYDVQQpEwVsb2dpbjEhMB8GCSqGSIb3DQEJARYSY29icmFAc25h
a2VvaWwuY29tMB4XDTExMDExMDAwMzI1NVoXDTIxMDEwNzAwMzI1NVowgZ8xCzAJ
BgNVBAYTAlVTMQswCQYDVQQIEwJWQTETMBEGA1UEBxMKQmxhY2tzYnVyZzESMBAG
A1UEChMJUmFja3NwYWNlMRcwFQYDVQQLEw5JbmZyYXN0cnVjdHVyZTEOMAwGA1UE
AxMFbG9naW4xDjAMBgNVBCkTBWxvZ2luMSEwHwYJKoZIhvcNAQkBFhJjb2JyYUBz
bmFrZW9pbC5jb20wgZ8wDQYJKoZIhvcNAQEBBQADgY0AMIGJAoGBAL0xIVIfh8rA
OCfc4BbWG+W+53iP9J6Fqhya5HSrYw3pdUCdimRBwQ0HoEnHndz2soRYc2Wtat8L
qqoS/qZMBbqerzEUFHumSKLADT3y8G1gkiGsb1fBZPmExPYyG/UQQUfK7CIM/L/m
W6Ji5ZEfTF9QPwHj3kVU99VUvm/BS8wXAgMBAAGjggEIMIIBBDAdBgNVHQ4EFgQU
dOvLRyxDa2Xso59PFLf22sZQ07wwgdQGA1UdIwSBzDCByYAUdOvLRyxDa2Xso59P
FLf22sZQ07yhgaWkgaIwgZ8xCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJWQTETMBEG
A1UEBxMKQmxhY2tzYnVyZzESMBAGA1UEChMJUmFja3NwYWNlMRcwFQYDVQQLEw5J
bmZyYXN0cnVjdHVyZTEOMAwGA1UEAxMFbG9naW4xDjAMBgNVBCkTBWxvZ2luMSEw
HwYJKoZIhvcNAQkBFhJjb2JyYUBzbmFrZW9pbC5jb22CCQDkTWTUaT8fOzAMBgNV
HRMEBTADAQH/MA0GCSqGSIb3DQEBBQUAA4GBAAVXIxOocwXi05004m9Znff6/cAj
2osr72g/Xux++lVqiSHf+T/R4QywsXy9//vKeXVEIyaaP9ImnWbbzHFFI+NStP4n
LILyv+/eOuZ6Dv7Vv6ZacjI3fexcXYr5VW52HHbb/M7G1ePAfdAixUHNH7lh58dY
WDzmJicksUYlyvI+
-----END CERTIFICATE-----
</ca-cert>
      <client-cert>-----BEGIN CERTIFICATE-----
MIIEDjCCA3egAwIBAgIBAzANBgkqhkiG9w0BAQUFADCBnzELMAkGA1UEBhMCVVMx
CzAJBgNVBAgTAlZBMRMwEQYDVQQHEwpCbGFja3NidXJnMRIwEAYDVQQKEwlSYWNr
c3BhY2UxFzAVBgNVBAsTDkluZnJhc3RydWN0dXJlMQ4wDAYDVQQDEwVsb2dpbjEO
MAwGA1UEKRMFbG9naW4xITAfBgkqhkiG9w0BCQEWEmNvYnJhQHNuYWtlb2lsLmNv
bTAeFw0xMTAxMTAwMDM3MzVaFw0yMTAxMDcwMDM3MzVaMIGfMQswCQYDVQQGEwJV
UzELMAkGA1UECBMCVkExEzARBgNVBAcTCkJsYWNrc2J1cmcxEjAQBgNVBAoTCVJh
Y2tzcGFjZTEXMBUGA1UECxMOSW5mcmFzdHJ1Y3R1cmUxDjAMBgNVBAMTBWxvY2Fs
MQ4wDAYDVQQpEwVsb2dpbjEhMB8GCSqGSIb3DQEJARYSY29icmFAc25ha2VvaWwu
Y29tMIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQCefsUr0T4oQUjKjW7Dpx0t
KwwafBF2HUW7CI75apeTjSBgYC1CHC6cggfFkUTFvndzspbGaeuJeYtvcvkAa2BD
p4jlSJgEXa+Uy1UAj1y06BePLNbKF4EfgEGf3eIWcdOtLYbOg4k33uNgto168iVO
owWOR+B2/z73NIHWxvtF3wIDAQABo4IBVjCCAVIwCQYDVR0TBAIwADAtBglghkgB
hvhCAQ0EIBYeRWFzeS1SU0EgR2VuZXJhdGVkIENlcnRpZmljYXRlMB0GA1UdDgQW
BBSRXbeuamcuma4yo5B8IYSGGT3fNjCB1AYDVR0jBIHMMIHJgBR068tHLENrZeyj
n08Ut/baxlDTvKGBpaSBojCBnzELMAkGA1UEBhMCVVMxCzAJBgNVBAgTAlZBMRMw
EQYDVQQHEwpCbGFja3NidXJnMRIwEAYDVQQKEwlSYWNrc3BhY2UxFzAVBgNVBAsT
DkluZnJhc3RydWN0dXJlMQ4wDAYDVQQDEwVsb2dpbjEOMAwGA1UEKRMFbG9naW4x
ITAfBgkqhkiG9w0BCQEWEmNvYnJhQHNuYWtlb2lsLmNvbYIJAORNZNRpPx87MBMG
A1UdJQQMMAoGCCsGAQUFBwMCMAsGA1UdDwQEAwIHgDANBgkqhkiG9w0BAQUFAAOB
gQApPAG1suVSPugJyQGfBaL8H+7VJdAGXnc6INX5s1AxJ3mvp4o6PQ7ytP4v/QkJ
ZVMgWV8immfa3PboFgT00qqpbC2Vbf4RR972IEQfGuJLLl4YLrJsbloV9hBamKS7
Z1lllmEHxFWpNK2FLSZNaeQABZyvzfZYkk6zsHoY8XsCBg==
-----END CERTIFICATE-----
</client-cert>
      <client-key>-----BEGIN RSA PRIVATE KEY-----
MIICXQIBAAKBgQCefsUr0T4oQUjKjW7Dpx0tKwwafBF2HUW7CI75apeTjSBgYC1C
HC6cggfFkUTFvndzspbGaeuJeYtvcvkAa2BDp4jlSJgEXa+Uy1UAj1y06BePLNbK
F4EfgEGf3eIWcdOtLYbOg4k33uNgto168iVOowWOR+B2/z73NIHWxvtF3wIDAQAB
AoGAf3tFykWl8ij4jHsP8Wz0CcWLGa5bOR64XIS4wyKaQoML3JjfLkKOtzHbYGzE
3Syi1bt6jKLbYZsSrRTT9SNorB3M2HI/uu1NHVyJ8fqxSJs9wQWv26XcMq6iPXR6
JQmiG44r0NoHtDOw0NCoo+9il4wjTIVSwN58x69EO1hsWokCQQDREYW73F536KzN
GSsLy+8VsaRiHCboi7lZwITGt4xFhykP/P5R/mNMTklVpJENuZH5jhiBr8r2O/XE
NQpIEZiFAkEAwhL4EnXax5p50g2CpkJM2B9F/p3IjjMs/sdUh4/RvAVkVAzz7uOh
TjtrL0T6480wA7rk3324IG5x4XTgXYVkEwJBAKkg7LgJ0N5d+xS8TIdxhctd9uZr
ccpj5iDGTmNXbwF8EurdNnvsODYtisPeqn2Y5o8ktYyMQrupy+rbIaMloOUCQAsI
pQ33oV6jy7VDi2AEePX4oTQeqF5dTnuVvZqPdK8p51BYBC5axrr56dggJdt5uPcd
UxHZxfQiE1tsF615ff0CQQCjeBskODATJkbN0kw+6FIF9m7QoEAYtJD1jLiY/2Sv
QRiYX+gvycrIph1yyIGA1qeHYnjhQp4ZijhcwSFUAAyF
-----END RSA PRIVATE KEY-----
</client-key>
      <created-at type="datetime">2011-01-09T19:37:32-05:00</created-at>
      <id type="integer">15</id>
      <interfacable-id type="integer">5</interfacable-id>
      <interfacable-type>Client</interfacable-type>
      <ptp-ip-addr>172.19.0.6</ptp-ip-addr>
      <updated-at type="datetime">2011-01-09T19:37:36-05:00</updated-at>
      <vpn-ip-addr>172.19.0.5</vpn-ip-addr>
    </vpn-network-interface>
  </vpn-network-interfaces>
</client>
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
  <openvpn-server type="boolean">false</openvpn-server> 
  <retry-count type="integer">0</retry-count> 
  <server-group-id type="integer">999</server-group-id> 
  <status>Online</status> 
  <updated-at type="datetime">2010-07-29T11:19:04-04:00</updated-at> 
</linux-server>
}
