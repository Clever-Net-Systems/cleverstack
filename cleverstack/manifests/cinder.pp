class cleverstack::cinder(
  $password      = '',
  $controllerint = '',
  $cinderpv      = '',
) {
  class { '::cinder::db::mysql':
    password      => $password,
    allowed_hosts => '%.clevernetsystems.com',
    mysql_module  => 2.2,
  }
  class { '::cinder::keystone::auth':
    password         => $password,
    email            => 'admin@clevernetsystems.com',
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
  }
  class { '::cinder':
    database_connection     => "mysql://cinder:${password}@${controllerint}/cinder",
    rabbit_password         => $password,
    rabbit_host             => $controllerint,
    rabbit_userid           => 'rabbitmq',
    verbose                 => true,
    mysql_module            => 2.2,
  }
  # Prevents taking too much time when erasing a volume (http://lists.openstack.org/pipermail/openstack-dev/2013-October/016452.html)
  # Prevents error messages about uninitialized volume driver
  class { '::cinder::config':
    cinder_config => {
      'DEFAULT/volume_clear' => { value => 'none' },
      'DEFAULT/volume_driver' => { value => 'cinder.volume.drivers.lvm.LVMISCSIDriver' },
    }
  }
  class { '::cinder::api':
    keystone_password  => $password,
    keystone_auth_host => $controllerint,
    enabled            => true,
  }
  class { '::cinder::scheduler':
    scheduler_driver => 'cinder.scheduler.simple.SimpleScheduler',
    enabled          => true,
  }
  package { 'lvm2':
    ensure => present,
  } ~>
  file { '/var/lib/cinder':
    ensure  => directory,
    owner   => 'cinder',
    group   => 'cinder',
    require => Package['cinder'],
  } ~>
  exec { "pvcreate $cinderpv":
    path        => ['/bin','/usr/bin','/sbin','/usr/sbin'],
    unless      => "pvdisplay | grep cinder-volumes",
    #refreshonly => true,
  } ~>
  exec { "vgcreate cinder-volumes $cinderpv":
    path        => ['/bin','/usr/bin','/sbin','/usr/sbin'],
    refreshonly => true,
  } ->
  class { '::cinder::volume': }
  class { '::cinder::volume::iscsi':
    iscsi_ip_address => $controllerint,
    volume_group     => 'cinder-volumes',
  }
}
