class cleverstack::glance(
  $password      = '',
  $controllerint = '',
  $domain        = '',
) {
  class { 'glance::db::mysql':
    password      => $password,
    allowed_hosts => "%.$domain",
    mysql_module  => 2.2,
  }
  class { 'glance::api':
    verbose           => true,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $password,
    sql_connection    => "mysql://glance:${password}@${controllerint}/glance",
    mysql_module      => 2.2,
  }
  class { 'glance::registry':
    verbose           => true,
    keystone_tenant   => 'services',
    keystone_user     => 'glance',
    keystone_password => $password,
    sql_connection    => "mysql://glance:${password}@${controllerint}/glance",
    mysql_module      => 2.2,
  }
  class { 'glance::backend::file': }
  class { 'glance::keystone::auth':
    password         => $password,
    email            => "admin@$domain",
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
  }
}
