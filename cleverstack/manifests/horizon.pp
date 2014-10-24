class cleverstack::horizon(
  $password      = '',
  $controllerint = '',
) {
  class { '::horizon':
    cache_server_ip       => '127.0.0.1',
    cache_server_port     => '11211',
    secret_key            => '12345',
    swift                 => true,
    django_debug          => 'True',
    api_result_limit      => '2000',
    neutron_options       => { 'enable_lb' => true, 'enable_firewall' => true, },
    keystone_url          => "http://${controllerint}:5000/v2.0",
    require               => Class['memcached'],
  } ->
  # https://bugs.launchpad.net/horizon/+bug/1324218
  file { '/usr/share/openstack-dashboard/openstack_dashboard/dashboards/admin/metering/templates/metering/daily.html':
    source => "puppet:///modules/cleverstack/daily.html",
    ensure => file,
    owner  => root,
    group  => root,
    mode   => 0644,
  }
}
