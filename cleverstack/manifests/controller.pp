class cleverstack::controller (
  $controllerext = 'controller-ext',
  $controllerint = 'controller-int',
  $computeint    = 'controller-int',
  $password      = 'password',
  $cinderpv      = 'NEPASSETROMPER',
  $forwarders    = '',
) {
  firewall { '8080 (PuppetDB)':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 8080,
  }
  firewall { '80 (Horizon)':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 80,
  }
  firewall { '6080 (novncproxy)':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 6080,
  }
  # Memcached
  class { 'memcached':
    listen_ip => $controllerint,
    tcp_port  => '11211',
    udp_port  => '11211',
  }
  # We need erlang otherwise RabbitMQ fails with a dependency error
  class { 'erlang': }
  file { '/usr/local/bin/netcreate':
    source => "puppet:///modules/cleverstack/netcreate",
    ensure  => file,
    owner   => root,
    group  => root,
    mode    => 0755,
  }
  file { '/usr/local/bin/netdelete':
    source => "puppet:///modules/cleverstack/netdelete",
    ensure  => file,
    owner   => root,
    group  => root,
    mode    => 0755,
  }
  file { '/usr/local/bin/stacktail':
    source => "puppet:///modules/cleverstack/stacktail",
    ensure => file,
    owner  => root,
    group  => root,
    mode   => 0755,
  }
  # Rabbit MQ
  class { '::nova::rabbitmq':
    userid             => 'rabbitmq',
    password           => $password,
    rabbitmq_class     => '::rabbitmq',
  }
  class { '::cleverstack::keystone':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::glance':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::nova':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::horizon':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::neutron':
    password      => $password,
    controllerint => $controllerint,
    computeint    => $computeint,
  }
  class { '::cleverstack::cinder':
    password      => $password,
    controllerint => $controllerint,
    cinderpv      => $cinderpv,
  }
  class { '::cleverstack::bind':
    forwarders  => $forwarders,
  }
  class { '::cleverstack::heat':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::ceilometer':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::openrc':
    admin_password  => $password,
    controller_node => $controllerint,
  }
  class { '::cleverstack::clevermon':
    admin_password  => $password,
    controller_node => $controllerint,
  }
}
