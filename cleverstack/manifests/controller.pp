class cleverstack::controller (
  $controllerext   = 'controller-ext',
  $ipcontrollerint = '0.0.0.0',
  $controllerint   = 'controller-int',
  $computeint      = 'controller-int',
  $password        = 'password',
  $cinderpv        = 'NEPASSETROMPER',
  $forwarders      = '',
  $domain          = '',
) {
  firewall { '1 eth1':
    proto   => 'all',
    iniface => 'eth1',
    action  => 'accept',
  }
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
#  firewall { '6082 (spiceproxy)':
#    proto  => 'tcp',
#    state  => ['NEW'],
#    action => 'accept',
#    port   => 6082,
#  }
  firewall { '6080 (novncproxy)':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 6080,
  }
  firewall { '8140 (Puppet)':
    proto  => 'tcp',
    state  => ['NEW'],
    action => 'accept',
    port   => 8140,
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
    domain        => $domain,
  }
  class { '::cleverstack::glance':
    password      => $password,
    controllerint => $controllerint,
    domain        => $domain,
  }
  class { '::cleverstack::nova':
    password      => $password,
    controllerint => $controllerint,
    domain        => $domain,
  }
  class { '::cleverstack::horizon':
    password      => $password,
    controllerint => $controllerint,
  }
  class { '::cleverstack::neutron':
    password        => $password,
    ipcontrollerint => $ipcontrollerint,
    controllerint   => $controllerint,
    computeint      => $computeint,
    domain          => $domain,
  }
  class { '::cleverstack::cinder':
    password      => $password,
    controllerint => $controllerint,
    cinderpv      => $cinderpv,
    domain        => $domain,
  }
  class { '::cleverstack::bind':
    forwarders  => $forwarders,
  }
  class { '::cleverstack::heat':
    password      => $password,
    controllerint => $controllerint,
    domain        => $domain,
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
  class { '::cleverstack::swift':
    password      => $password,
    controllerint => $controllerint,
    ipcontrollerint => $ipcontrollerint,
  }
}
