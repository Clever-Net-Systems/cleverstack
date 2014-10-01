class cleverstack::keystone(
  $password      = '',
  $controllerint = '',
  $domain        = '',
) {
  class { '::keystone::db::mysql':
    dbname        => 'keystone',
    user          => 'keystone',
    password      => $password,
    allowed_hosts => "%.$domain",
    # Prevents the following error: Error 400 on SERVER: Could not find class mysql::python
    mysql_module  => 2.2,
  }
  class { '::keystone':
    verbose             => true,
    debug               => true,
    database_connection => "mysql://keystone:${password}@${controllerint}/keystone",
    admin_token         => '84833d78d65ef3b009a6',
    enabled             => true,
    mysql_module        => 2.2,
  }
  class { '::keystone::roles::admin':
    email    => "admin@$domain",
    password => $password,
  }
  class { '::keystone::endpoint':
    public_url => "http://${controllerint}.$domain:5000/",
    admin_url  => "http://${controllerint}.$domain:35357/",
  }
}
