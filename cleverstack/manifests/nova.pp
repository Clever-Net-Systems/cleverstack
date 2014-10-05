class cleverstack::nova(
  $password      = '',
  $controllerint = '',
  $domain = '',
) {
  class { 'nova::db::mysql':
    password      => $password,
    allowed_hosts => "%.$domain",
    mysql_module  => 2.2,
  }
  class { '::nova':
    database_connection => "mysql://nova:${password}@${controllerint}/nova?charset=utf8",
    glance_api_servers  => "http://${controllerint}:9292",
    image_service       => 'nova.image.glance.GlanceImageService',
    memcached_servers   => ["${controllerint}:11211"],
    rabbit_hosts        => ["${controllerint}"],
    rabbit_userid       => "rabbitmq",
    rabbit_password     => $password,
    debug               => true,
    verbose             => true,
    mysql_module        => 2.2,
  }
  class { '::nova::api':
    admin_password                       => $password,
    auth_host                            => "${controllerint}",
    enabled                              => true,
    admin_tenant_name                    => 'services',
    neutron_metadata_proxy_shared_secret => $password,
  }
#  class { '::nova::vncproxy':
#    host    => $controllerext,
#    enabled => true,
#  }
  package { 'spice-html5':
    ensure => installed,
  }
  class { '::nova::spicehtml5proxy':
    enabled => true,
    host    => $controllerext,
    require => Package['spice-html5'],
  }
  class { [
    'nova::scheduler',
    'nova::objectstore',
    'nova::cert',
    'nova::consoleauth',
    'nova::conductor'
  ]:
    enabled => true,
  }
#  class { 'nova::compute':
#    enabled                       => true,
#    vnc_enabled                   => true,
#    #vnc_keymap                    => 'fr-ch',
#    vncproxy_host                 => "controller.$domain",
#    vncserver_proxyclient_address => $controllerint,
#    #novncproxy_base_url           => "http://controller.$domain:6080/vnc_auto.html",
#    #xvpvncproxy_base_url          => "http://controller.$domain:6081/console",
#    #vncserver_listen              => $controllerint,
#  }
  class { 'nova::compute':
    enabled                       => true,
    vnc_enabled                   => false,
  }
  class { 'nova::compute::spice':
    agent_enabled                 => true,
    server_listen                 => '0.0.0.0',
    server_proxyclient_address    => $controllerint,
    keymap                        => 'fr_CH',
    proxy_host                    => "controller.$domain",
  }
  class { 'nova::compute::libvirt':
    migration_support => true,
    vncserver_listen  => '0.0.0.0',
  }
  class { '::nova::compute::neutron': }
  class { '::nova::network::neutron':
    neutron_admin_password => $password,
    neutron_region_name    => 'RegionOne',
    neutron_admin_auth_url => "http://${controllerint}:35357/v2.0",
    neutron_url            => "http://${controllerint}:9696",
    vif_plugging_is_fatal  => false,
    vif_plugging_timeout   => '0',
  }
  class { '::nova::keystone::auth':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    tenant           => 'services',
    region           => 'RegionOne',
  }
}
