cleverstack
===========

Deploy OpenStack in a rented server scenario.

This Puppet module and install script will allow you to setup an OpenStack demo that runs in the following environment:

* 2 servers hosted by a company such as www.ovh.com, www.online.net or www.1and1.com
* The servers have a single IP address, but you can buy additional failover IPs that do not necessarily follow each other
* Each server has 2 NICs. eth0 is the public IP and eth1 is a private connection (often with a higher MTU) between the two servers
* We're using CentOS 6 and OpenStack Icehouse
* All OpenStack components go on the first node. The second node has a second Nova (compute) instance

Install steps:

* Install a minimal CentOS 6.5 on both nodes with a / partition of 100GB. The remaining space will be made into a PV for Cinder.

* On controller, download the controller installation script:
```
# wget --no-check-certificate https://raw.githubusercontent.com/clevernet/cleverstack/master/install.sh
```
* Adapt the script to your needs (read the comments in the script) and execute it:
```
# chmod 755 install.sh
# ./install.sh
```

* Once the installation is finished, go to http://controller.yourdomain.com/ and login as admin with the password you specified in the installation script
* Create a keypair
* Launch an instance (attach its virtual NIC to intnet)
* Associate floating IP 10.88.15.3 (the first floating IP) to the instance

* You should now be able to:
  * Ping www.google.com from the instance
  * SSH into the instance from any public IP address by connecting to your first failover IP
