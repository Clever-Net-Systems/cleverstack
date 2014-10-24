class cleverstack::swift(
  $password        = '',
  $controllerint   = '',
  $ipcontrollerint = '',
) {
  class { '::swift::keystone::auth':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
    tenant           => 'services',
  }
  class { '::swift':
    swift_hash_suffix => $password,
  }
  class { '::swift::proxy':
    proxy_local_net_ip => $controllerint,
    pipeline           => [ 'catch_errors', 'healthcheck', 'cache', 'ratelimit', 'swift3', 'authtoken', 'keystone', 'proxy-server' ],
    workers            => 1,
    require            => Class['::swift::ringbuilder'],
  }
  class { [ '::swift::proxy::catch_errors', '::swift::proxy::healthcheck' ]: }
  class { '::swift::proxy::cache':
    memcache_servers => [ $controllerint ]
  }
  class { [ '::swift::proxy::ratelimit', '::swift::proxy::swift3' ]: }
  class { '::swift::proxy::authtoken':
    admin_password => $password,
    auth_host      => $controllerint,
  }
  class { '::swift::proxy::keystone': }
  # Storage resources collection
  Ring_object_device <<| |>>
  Ring_container_device <<| |>>
  Ring_account_device <<| |>>
  class { 'swift::ringbuilder':
    part_power     => 18,
    replicas       => 3,
    min_part_hours => 1,
    require        => Class['::swift'],
  }
  class { 'swift::ringserver':
    local_net_ip => $controllerint,
  }
  # First Swift storage node
  swift::storage::loopback { '1':
    base_dir     => '/srv/swift-loopback',
    mnt_base_dir => '/srv/node',
    byte_size    => 1024,
    seek         => 10000,
    fstype       => 'ext4',
    require      => Class['::swift'],
  }
  class { '::swift::storage::all':
    storage_local_net_ip => $controllerint
  }
  @@ring_object_device { "$ipcontrollerint:6000/1":
    zone   => 1,
    weight => 1,
  }
  @@ring_container_device { "$ipcontrollerint:6001/1":
    zone   => 1,
    weight => 1,
  }
  @@ring_account_device { "$ipcontrollerint:6002/1":
    zone   => 1,
    weight => 1,
  }
  swift::ringsync { ['account','container','object']: 
    ring_server => $controllerint, 
  }
}
