class cleverstack::heat(
  $password      = '',
  $controllerint = '',
  $domain        = '',
) {
  class { 'heat::db::mysql':
    dbname        => 'heat',
    user          => 'heat',
    password      => $password,
    allowed_hosts => "%.$domain",
    mysql_module  => 2.2,
  } ->
  class { '::heat':
    sql_connection    => "mysql://heat:${password}@${controllerint}/heat",
    rabbit_host       => $controllerint,
    rabbit_userid     => 'rabbitmq',
    rabbit_password   => $password,
    debug             => True,
    verbose           => True,
    keystone_host     => $controllerint,
    keystone_password => $password,
    keystone_ec2_uri  => "http://${controllerint}:5000/v2.0",
    mysql_module      => '2.2',
  }
  class { '::heat::keystone::auth':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
  }
  class { '::heat::keystone::auth_cfn':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
  }
  class { '::heat::api':
    bind_host => $controllerint,
  }
  class { '::heat::api_cfn':
    bind_host => $controllerint,
    workers   => 1,
  }
  class { '::heat::engine':
    heat_metadata_server_url      => "http://${controllerint}:8000",
    heat_waitcondition_server_url => "http://${controllerint}:8000/v1/waitcondition",
    heat_watch_server_url         => "http://${controllerint}:8003",
    auth_encryption_key           => $password,
  }
}
