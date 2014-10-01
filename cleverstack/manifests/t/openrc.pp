# Original version is https://github.com/puppetlabs/puppetlabs-openstack/blob/master/manifests/resources/auth_file.pp
class cleverstack::openrc (
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
  file { '/root/openrc':
    owner   => 'root',
    group   => 'root',
    mode    => '0700',
    content => template("cleverstack/openrc"),
  }
}
