class cleverstack::clevermon (
  $admin_password,
  $controller_node          = '127.0.0.1',
  $admin_user               = 'admin',
  $admin_tenant             = 'openstack',
  $region_name              = 'RegionOne',
  $use_no_cache             = true,
  $cinder_endpoint_type     = 'publicURL',
  $glance_endpoint_type     = 'publicURL',
  $keystone_endpoint_type   = 'publicURL',
  $nova_endpoint_type       = 'publicURL',
  $neutron_endpoint_type    = 'publicURL',
) {
#  file { '/etc/cron.d/clevermon':
#    owner   => 'root',
#    group   => 'root',
#    mode    => '0644',
#    content => template("cleverstack/clevermon"),
#  }
  file { '/etc/httpd/conf.d/monitor.conf':
    source => "puppet:///modules/cleverstack/monitor.conf",
    ensure => file,
    owner  => 'root',
    group  => root,
    mode   => '0644',
  }
  package { [ 'net-snmp-utils', 'php', 'rrdtool' ]:
    ensure => installed,
  }
}
