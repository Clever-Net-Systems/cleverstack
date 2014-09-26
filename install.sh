#!/bin/bash

###
# Change the following parameters to adapt the script to your setup:
###

# The IP address of the public interface of the controller node
CONTROLLER_PUBIP=62.1.2.3
# The IP address of the private interface of the controller node
CONTROLLER_PRVIP=10.1.2.3
# The MAC address of the public interface of the controller node
CONTROLLER_PUBHWADDR=AB:CD:EF:12:34:56
# The MAC address of the private interface of the controller node
CONTROLLER_PRVHWADDR=AB:CD:EF:12:34:57
# The IP address of the public interface of the compute node
COMPUTE1_PUBIP=62.1.2.4
# The IP address of the private interface of the compute node
COMPUTE1_PRVIP=10.1.2.4
# The MAC address of the public interface of the compute node
COMPUTE1_PUBHWADDR=AB:CD:EF:12:34:58
# The MAC address of the private interface of the compute node
COMPUTE1_PRVHWADDR=AB:CD:EF:12:34:59
# The DNS Domain in which the nodes live
DOMAIN=yourdomain.com
# The MTU of the private network (1500 if unknown)
PRVMTU=1500
# Network parameters of the controller
CONTROLLER_DNS1=62.1.3.5
CONTROLLER_DNS2=62.1.3.6
CONTROLLER_GW=62.1.2.254
# Network parameters of the compute node
COMPUTE1_DNS1=62.1.3.5
COMPUTE1_DNS2=62.1.3.6
COMPUTE1_GW=62.1.2.254
# The failover IPs associated to the controller node
FAILOVERIPS=(212.1.2.3 212.1.3.4)
# The global password
PASSWORD=changeme
# The partition that should be used as a PV for Cinder (Warning, this partition will be destroyed by the installation script)
CINDERPV=/dev/sda2

# Do not change anything beyond this point

usage() {
	echo "Usage: $0 n, where n is 0 for a controller installation or any positive integer for the nth compute node"
	exit 1
}

[ $# -eq 1 ] || usage
[[ $1 =~ ^[0-9]+$ ]] || usage

if [ $1 -eq 0 ]; then
	###
	# CONTROLLER NODE INSTALLATION
	###
	echo "Installing controller node"
	cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.0.1	controller.$DOMAIN controller
$CONTROLLER_PUBIP	controller-ext.$DOMAIN controller-ext
$CONTROLLER_PRVIP	controller-int.$DOMAIN controller-int
$COMPUTE1_PUBIP	compute1-ext.$DOMAIN compute1-ext
$COMPUTE1_PRVIP	compute1-int.$DOMAIN compute1-int
EOF

	cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE=eth0
HWADDR=$CONTROLLER_PUBHWADDR
BOOTPROTO=static
HOSTNAME=controller
IPADDR=$CONTROLLER_PUBIP
IPV6INIT=yes
MTU=1500
NETMASK=255.255.255.0
DNS1=$CONTROLLER_DNS1
DNS2=$CONTROLLER_DNS2
GATEWAY=$CONTROLLER_GW
NM_CONTROLLED=no
ONBOOT=yes
EOF

	cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
DEVICE="eth1"
BOOTPROTO="dhcp"
HWADDR=$CONTROLLER_PRVHWADDR
NM_CONTROLLED=no
ONBOOT=yes
MTU=$PRVMTU
TYPE="Ethernet"
EOF

	cat > /etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=controller.$DOMAIN
GATEWAY=$CONTROLLER_GW
EOF

	rpm -ivh https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
	yum clean all
	yum -y update

	cat >> /root/.bashrc <<EOF

# Bugfix https://bugs.launchpad.net/puppet-openstack/+bug/1201500
export PATH=$PATH:/usr/lib/rabbitmq/lib/rabbitmq_server-3.1.5/sbin
EOF

	hostname controller.$DOMAIN
	export HOSTNAME=controller

	###
	# Install Puppet server and required modules
	###
	yum -y install puppet-server
	rm -rf /var/lib/puppet/ssl
	service puppetmaster restart
	chkconfig puppetmaster on

	cat >> /etc/puppet/puppet.conf <<EOF
    server = controller.$DOMAIN
    report = false
    pluginsync = true

[master]
    autosign = true
EOF

	puppet module install puppetlabs-apache
	puppet module install puppetlabs-apt
	puppet module install puppetlabs-cinder
	puppet module install puppetlabs-firewall
	puppet module install puppetlabs-glance
	puppet module install puppetlabs-horizon
	puppet module install puppetlabs-neutron
	puppet module install puppetlabs-postgresql
	puppet module install puppetlabs-mongodb
	puppet module install puppetlabs-ceilometer
	puppet module install puppetlabs-heat
	puppet module install thias-bind

	yum -y install svn
	wget --no-check-certificate https://raw.githubusercontent.com/clevernet/cleverstack/master/site.pp -O /etc/puppet/manifests/site.pp
	sed -i "s/###PASSWORD###/$PASSWORD/" /etc/puppet/manifests/site.pp
	sed -i "sX###CINDERPV###X${CINDERPV}X" /etc/puppet/manifests/site.pp
	sed -i "s/###FORWARDER###/$CONTROLLER_DNS1/" /etc/puppet/manifests/site.pp
	sed -i "s/###DOMAIN###/$DOMAIN/" /etc/puppet/manifests/site.pp
	svn export --force https://github.com/clevernet/cleverstack/trunk/cleverstack /etc/puppet/modules/cleverstack
	find /etc/puppet/modules -type f -exec chmod 644 {} \;
	find /etc/puppet/modules -type d -exec chmod 755 {} \;

	# We need to bring eth1 up before the Puppet run because daemons need to bind on it
	ifup eth1
	# The partition for Cinder needs to be unmounted
	umount $CINDERPV
	puppet agent --test

	# Create the br-ex OVS bridge (this cannot currently be done from the cleverstack module because we need to manually copy the hardware address of eth0 to br-ex). We modify ifcfg-br-ex and restart in the same command otherwise we lose connectivity
	puppet apply -e 'vs_bridge { 'br-ex': ensure => present }'
	puppet apply -e 'vs_port { 'eth0': ensure => present, bridge => 'br-ex', keep_ip => true }' && sed -i "s/..:..:..:..:..:../`ip a show dev eth0 | grep -o ..:..:..:..:..:.. | head -1`/" /etc/sysconfig/network-scripts/ifcfg-br-ex && service network restart
	# This will edit /etc/sysconfig/network-scripts/ifcfg-br-ex and change the OVS_EXTRA line to match the MAC address of eth0, and will prevent the switch behind the server from blocking traffic to/from an unkwown MAC address.

	# /usr/local/bin/stackrestart is just a simple script that restarts all OpenStack services in the right order
	stackrestart

	# Add additional IPs to the br-ex bridge (we need to add all our failover IPs as well as 10.88.15.1 which is an IP from extnet, our fake external network)
	for fip in ${FAILOVERIPS[@]}; do
		ip addr add $fip/24 dev br-ex
	done
	ip addr add 10.88.15.1/24 dev br-ex
	# Restart named so it can attach to 10.88.15.1
	service named restart

	# Setup double SNAT solution (http://dachary.org/?p=2466)
	iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
	destip=3
	for fip in ${FAILOVERIPS[@]}; do
		# Back and forth NAT between IPs from our fake external network and our failover IPs
		iptables -t nat -A POSTROUTING -s 10.88.15.$destip/32 -j SNAT --to-source $fip
		iptables -t nat -A PREROUTING -d $fip/32 -j DNAT --to-destination 10.88.15.$destip
		destip=$((destip + 1))
	done
	# Any instance that isn't assigned a floating IP will SNAT through the first failover IP
	iptables -t nat -A POSTROUTING -s 10.88.15.0/24 -j SNAT --to-source ${FAILOVERIPS[0]}
	iptables -I FORWARD 1 -s 10.88.15.0/24 -j ACCEPT
	iptables -I FORWARD 2 -d 10.88.15.0/24 -j ACCEPT

	# Allow DNS traffic from cloud instances trough dnsmasq, to our intermediary DNS on 10.88.15.1
	iptables -I INPUT 3 -s 10.88.15.2 -d 10.88.15.1 -p tcp --dport 53 -j ACCEPT
	iptables -I INPUT 3 -s 10.88.15.2 -d 10.88.15.1 -p udp --dport 53 -j ACCEPT

	###
	# ManageIQ specifics
	###

	# Allow traffic to Keystone for ManageIQ instance
	iptables -I INPUT 3 -s 10.88.15.0/24 -d 10.88.15.1 -p tcp --dport 5000 -j ACCEPT
	iptables -I INPUT 3 -s 10.88.15.0/24 -d 10.88.15.1 -p tcp --dport 35357 -j ACCEPT
	iptables -I INPUT 3 -s 10.88.15.0/24 -d 10.88.15.1 -p tcp --dport 9696 -j ACCEPT
	iptables -I INPUT 3 -s 10.88.15.0/24 -d 10.88.15.1 -p tcp --dport 9292 -j ACCEPT
	iptables -I INPUT 3 -s 10.88.15.0/24 -d 10.88.15.1 -p tcp --dport 8774 -j ACCEPT
	iptables -I INPUT 3 -s 10.88.15.0/24 -d 10.88.15.1 -p tcp --dport 8776 -j ACCEPT

	# Add Admin role for user admin in services tenant for ManageIQ
	keystone user-role-add --user admin --tenant services --role admin

	# Create the virtual network
	source /root/openrc
	netcreate

	# Download useful cloud images
	wget http://download.cirros-cloud.net/0.3.2/cirros-0.3.2-x86_64-disk.img
	wget http://manageiq.org/download/manageiq-openstack-devel.qc2
	wget ftp://ftp.free.fr/mirrors/ftp.centos.org/6.5/isos/x86_64/CentOS-6.5-x86_64-minimal.iso
	wget https://dl.fedoraproject.org/pub/fedora/linux/releases/20/Images/x86_64/Fedora-x86_64-20-20131211.1-sda.qcow2
	wget https://fedorapeople.org/groups/heat/prebuilt-jeos-images/F17-x86_64-cfntools.qcow2
	glance image-create --name CirrOS --is-public True --disk-format=raw --container-format=bare --file cirros-0.3.2-x86_64-disk.img --progress
	glance image-create --name ManageIQ --is-public True --disk-format=qcow2 --container-format=bare --file cirros-0.3.2-x86_64-disk.img --progress
	glance image-create --name CentOS65 --is-public True --disk-format=iso --container-format=bare --file CentOS-6.5-x86_64-minimal.iso --progress
	glance image-create --name Fedora20 --is-public True --disk-format=qcow2 --container-format=bare --file Fedora-x86_64-20-20131211.1-sda.qcow2 --progress
	glance image-create --name Fedora17 --is-public True --disk-format=qcow2 --container-format=bare --file F17-x86_64-cfntools.qcow2 --progress
else
	###
	# COMPUTE NODE INSTALLATION
	###
	echo "Installing compute node $1"
	cat > /etc/hosts <<EOF
127.0.0.1   localhost localhost.localdomain localhost4 localhost4.localdomain4
::1         localhost localhost.localdomain localhost6 localhost6.localdomain6
127.0.0.1	compute1.$DOMAIN compute1
$CONTROLLER_PUBIP	controller-ext.$DOMAIN controller-ext controller
$CONTROLLER_PRVIP	controller-int.$DOMAIN controller-int
$COMPUTE1_PUBIP	compute1-ext.$DOMAIN compute1-ext
$COMPUTE1_PRVIP	compute1-int.$DOMAIN compute1-int
EOF

	cat > /etc/sysconfig/network-scripts/ifcfg-eth0 <<EOF
DEVICE=eth0
HWADDR=$COMPUTE1_PUBHWADDR
BOOTPROTO=static
HOSTNAME=controller
IPADDR=$COMPUTE1_PUBIP
IPV6INIT=yes
MTU=1500
NETMASK=255.255.255.0
DNS1=$COMPUTE1_DNS1
DNS2=$COMPUTE1_DNS2
GATEWAY=$COMPUTE1_GW
NM_CONTROLLED=no
ONBOOT=yes
EOF

	cat > /etc/sysconfig/network-scripts/ifcfg-eth1 <<EOF
DEVICE="eth1"
BOOTPROTO="dhcp"
HWADDR=$COMPUTE1_PRVHWADDR
NM_CONTROLLED=no
ONBOOT=yes
MTU=$PRVMTU
TYPE="Ethernet"
EOF

	cat > /etc/sysconfig/network <<EOF
NETWORKING=yes
HOSTNAME=compute1.$DOMAIN
GATEWAY=$COMPUTE1_GW
EOF

	rpm -ivh https://yum.puppetlabs.com/el/6/products/x86_64/puppetlabs-release-6-7.noarch.rpm
	yum clean all
	yum -y update

	hostname compute1.$DOMAIN
	export HOSTNAME=compute1

	yum -y install puppet
	cat >> /etc/puppet/puppet.conf <<EOF
    server = controller.$DOMAIN
    report = false
    pluginsync = true
EOF
	ifup eth1
	puppet agent --test

	# /usr/local/bin/stackrestart is just a simple script that restarts all OpenStack services in the right order
	stackrestart
fi
