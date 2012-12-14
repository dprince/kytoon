# Kytoon

Create small virtual server groups

## Description

Provides both a CLI (bin/kytoon) and set of rake tasks to help automate the creation and configuration of virtual server groups. Kytoon provides the ability to create projects that can be used by team members and continuous integration systems to create similar (if not identical) groups of servers for development and/or testing. Configuration information is stored in JSON and YAML formats which can be easily parsed, edited, and version controlled.

Inspired by and based on the Chef VPC Toolkit.

## Features

* Multiple providers (see below)
* A CLI with matching set of rake tasks.
* Create server groups with multiple nodes.
* Automatically injects your ssh into each server group.
* Configures hostnames (host files) on nodes within each group. Once you ssh
  into the group use preconfigured hostnames to access all the nodes.

## Provider support

- Libvirt: manage instances on local machine w/ libvirt, virt-clone, and libguestfs
- XenServer: manage instances on a remote XenServer box (via ssh)
- OpenStack: create instances in the cloud.

## Installation

Quick install on Fedora:

    yum install -y rubygems ruby-devel gcc gcc-c++ libxslt-devel
    gem install kytoon

    *NOTE: Kytoon has been tested with Fog 1.8.0+ only (1.9.0 will be required to work with Rackspace's OpenStack Cloud)

Create a .kytoon.conf file in your $HOME directory.

        # The default group type.
        # Set to one of: openstack, libvirt, xenserver
        group_type: openstack

        # Openstack Settings
        openstack_url: <auth_url>
        openstack_username: <username>
        openstack_password: <password>
        openstack_network_name: public # Optional: defaults to public
        openstack_keypair_name: < keyname > # Optional: file injection via personalities is the default
        openstack_security_groups: ['', ''] # Optional: Array of security group names
        openstack_ip_type: 4 # IP type (4 or 6): defaults to 4
        openstack_build_timeout: 480 # Server build timeout. Defaults to: 480
        openstack_ping_timeout: 60 # Server build timeout. Defaults to: 60
        openstack_service_name: < name > # Optional: default is None... some clouds have multiple 'compute' services so this may be required
        openstack_service_type: compute # Optional: default is 'compute'
        openstack_region: < region name > # Optional

        # Libvirt settings
        # Whether commands to create local group should use sudo
        libvirt_use_sudo: False

## Defining server groups

Server group config files are used to define how Kytoon configures
each server group.  These files typically live inside of project are
provider specific. The config files control things like memory, hostname,
flavor, etc. Each group should define identify one instance as the 'gateway' host which marks it as the primary access point for SSH access into the group.

By default Kytoon looks for config/server_group.json in the current directory.
You can override this with Rake using GROUP_CONFIG or bin/kytoon using --group-config.

Below are example server_group.json config files for each provider.

For Openstack:

```bash

	cat > config/server_group.json <<-"EOF_CAT"
	{
	"name": "Fedora",
	"servers": [
		{
		"hostname": "nova1",
		"image_ref": "1234",
		"flavor_ref": "5678",
		"gateway": "true"
		},
		{
		"hostname": "compute1",
		"image_ref": "1234",
		"flavor_ref": "5678"
		}
	]
	}
	EOF_CAT
```

For Libvirt (uses libvirt DHCP server for instance IP configuration):

NOTE: Kytoon assumes you are using NAT networking for your libvirt instances. If you use bridged networking the IP discovery mechanism will fail.

```bash

	cat > config/server_group.json <<-"EOF_CAT"
	{
	"name": "Fedora",
	"servers": [
		{
		"hostname": "nova1",
		"memory": "1",
		"gateway": "true",
		"original_xml": "/home/dprince/f17.xml",
		"create_cow": "true"
		}
	]
	}
	EOF_CAT
```

For XenServer (uses Openstack Guest agent for instance configuration):
```bash

        cat > config/server_group.json <<-"EOF_CAT"
	{
	"name": "Fedora",
	"netmask": "255.255.255.0",
	"gateway": "192.168.0.1",
	"broadcast": "192.168.0.127",
	"dns_nameserver": "8.8.8.8",
	"network_type": "static",
	"public_ip_bridge": "xenbr0",
	"bridge": "xenbr1",
	"servers": [
		{
		"hostname": "login",
		"image_path": "/images/fedora-agent2.xva",
		"ip_address": "192.168.0.2",
		"mac": "e2:6d:71:67:7e:66"
		},
		{
		"hostname": "nova1",
		"image_path": "/images/fedora-agent2.xva",
		"ip_address": "192.168.0.3",
		"mac": "e2:ad:a1:a7:ae:67"
		}
	    ]
	}
	EOF_CAT
```

## Command line

The following options are supported on the command line:

	kytoon create       # Create a new server group.
	kytoon delete       # Delete a server group.
	kytoon help [TASK]  # Describe available tasks or one specific task
	kytoon ip           # Print the IP address of the gateway server
	kytoon list         # List existing server groups.
	kytoon show         # Print information for a server group.
	kytoon ssh          # SSH into a group.

## Rakefile configuration

To include Kytoon rake tasks in your own project add the following to your
Rakefile:

	KYTOON_PROJECT = "#{File.dirname(__FILE__)}" unless defined?(KYTOON_PROJECT)
	require 'rubygems'
	require 'kytoon'
	include Kytoon
	Dir[File.join("#{Kytoon::Version::KYTOON_ROOT}/rake", '*.rake')].each do  |rakefile|
		import(rakefile)
	end

## Rake Tasks

Example commands:

* Create a new server group.

	$ rake kytoon:create

* List your currently running server groups.

	$ rake kytoon:list

* SSH into the current (most recently created) server group

	$ rake kytoon:ssh

* SSH into a server group with an ID of 3

	$ rake kytoon:ssh GROUP_ID=3

* Delete the server group with an ID of 3

	$ rake kytoon:delete GROUP_ID=3


## Bash Automation Script

The following is an example bash script to spin up a group and run commands via SSH.

```bash
        #!/bin/bash
        # override the group type specified in .kytoon.conf
        export GROUP_TYPE=libvirt

        trap "rake kytoon:delete" INT TERM EXIT # cleanup the group on exit

        # create a server group (uses config/server_group.json)
        rake kytoon:create

        # create a server group with alternate json file
        rake kytoon:create GROUP_CONFIG=config/my_group.json

        # Run some scripts on the login server
        rake kytoon:ssh bash <<-EOF_BASH
                echo 'It works!'
        EOF_BASH
```

## Copyright

Copyright (c) 2012 Red Hat Inc. See LICENSE.txt for further details.
