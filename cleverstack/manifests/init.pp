###
# Puppet manifest for installing OpenStack on two nodes with the following properties:
# * The 2 nodes are rented at companies such as ovh.com or online.net
# * The 2 nodes have direct Internet access and only one public IP address on eth0
# * The 2 nodes have a second interface (eth1) connected together on a private network
# * A number of IP "failover" addresses are available and assigned to the controller
# This Puppet manifest is compatible with RHEL6.5 and with the Icehouse version of OpenStack
# Misc:
# * A neutron router attached to the fake external network will show the router_gateway interface down. This is normal.
###

# TODO Faire en sorte que le NTP soit tout de suite démarré avec tinker panic 0 (pour la VM)

class cleverstack (
  $controllerint = 'controller-int',
  $password = 'password',
) {
#  package {"puppetlabs-release-6-10.noarch":
#    ensure => absent,
#  }
  class { 'epel': } ->
  package { [ 'htop', 'multitail' ]:
    ensure => installed,
    require => Class['epel'],
  }
  package { ['ntp']:
    ensure => installed,
  } ->
  service { 'ntpd':
    ensure  => running,
    enable  => true,
    require => Package['ntp'],
  }
  Exec { path => '/usr/bin:/usr/sbin:/bin:/sbin:/usr/lib/rabbitmq/lib/rabbitmq_server-3.1.5/sbin', }
  ::sysctl::value { 'net.ipv4.ip_forward':
    value     => '1',
  }
  ::sysctl::value { 'net.ipv4.conf.default.rp_filter':
    value     => '1',
  }
  ::sysctl::value { 'net.ipv4.conf.all.rp_filter':
    value     => '1',
  }
  yumrepo { 'rdo-release':
    baseurl  => "http://repos.fedorapeople.org/repos/openstack/openstack-icehouse/epel-6/",
    descr    => "OpenStack Icehouse Repository",
    enabled  => 1,
    gpgcheck => 1,
    gpgkey   => "file:///etc/pki/rpm-gpg/RPM-GPG-KEY-RDO-Icehouse",
    priority => 98,
    notify   => Exec['yum_refresh'],
#    require => Package['puppetlabs-release-6-10.noarch'],
  }
  file { "/etc/pki/rpm-gpg/RPM-GPG-KEY-RDO-Icehouse":
    source => "puppet:///modules/cleverstack/RPM-GPG-KEY-RDO-Icehouse",
    owner  => root,
    group  => root,
    mode   => '0644',
    before => Yumrepo['rdo-release'],
  }
  exec { 'yum_refresh':
    command     => '/usr/bin/yum clean all',
    refreshonly => true,
  }
  Exec['yum_refresh'] -> Package<||>
  Yumrepo['rdo-release'] -> Package<||>
  # This is necessary because we need a more recent version of iproute to support namespaces
  package { 'iproute':
    ensure => latest,
    require => Yumrepo['rdo-release'],
  }
  # MySQL
  # We need to set the default engine to InnoDB because of https://bugs.launchpad.net/neutron/+bug/1288358
  class { 'mysql::server':
    root_password      => $password,
    override_options   => { 'mysqld' => { 'bind_address' => $controllerint, 'default-storage-engine' => 'InnoDB' } },
  } ->
  class { 'mysql::server::account_security': }
  file { '/usr/local/bin/stackrestart':
    source => "puppet:///modules/cleverstack/stackrestart",
    ensure => file,
    owner  => 'root',
    group  => root,
    mode   => '0755',
  }
}
