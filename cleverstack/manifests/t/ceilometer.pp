class cleverstack::ceilometer(
  $password      = '',
  $controllerint = '',
) {
  class {'::mongodb::globals':
    manage_package_repo => true,
  } ->
  class { '::mongodb::server':
    bind_ip => ['127.0.0.1', $controllerint],
  } ->
  class { '::mongodb::client': } ->
  class { '::ceilometer::keystone::auth':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
  }
  class { '::ceilometer::agent::central': }
  class { '::ceilometer::expirer':
    time_to_live => '2592000'
  }
  class { '::ceilometer::alarm::notifier': }
  class { '::ceilometer::alarm::evaluator': }
  class { '::ceilometer::collector': }
  class { '::ceilometer':
    metering_secret => $password,
    debug           => True,
    verbose         => True,
    rabbit_hosts    => [$controllerint],
    rabbit_userid   => 'rabbitmq',
    rabbit_password => $password,
  }
  class { '::ceilometer::api':
    enabled           => true,
    keystone_host     => $controllerint,
    keystone_password => $password,
  }
  class { '::ceilometer::db':
    database_connection => "mongodb://${controllerint}:27017/ceilometer",
    mysql_module        => '2.2',
  }
  class { '::ceilometer::agent::auth':
    auth_url      => "http://${controllerint}:5000/v2.0",
    auth_password => $password,
    auth_region   => 'RegionOne',
  } ->
  class { '::ceilometer::agent::compute': }
  mongodb_database { 'ceilometer':
    ensure  => present,
    tries   => 20,
    require => Class['mongodb::server'],
  }
  mongodb_user { 'ceilometer':
    ensure        => present,
    password_hash => mongodb_password('ceilometer', $password),
    database      => 'ceilometer',
    roles         => ['readWrite', 'dbAdmin'],
    tries         => 10,
    require       => [Class['mongodb::server'], Class['mongodb::client']],
  }
  Class['::mongodb::server'] -> Class['::mongodb::client'] -> Exec['ceilometer-dbsync']
}
