class cleverstack::compute (
  $controllerext = 'controller-ext',
  $controllerint = 'controller-int',
  $password = 'password',
  $domain = '',
) {
#  firewall { '1 eth1':
#    proto   => 'all',
#    iniface => 'eth1',
#    action  => 'accept',
#  }
  Exec { path => '/usr/bin:/usr/sbin:/bin:/sbin', }
  class { 'nova':
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
    enabled                              => false, # because compute node
    admin_tenant_name                    => 'services',
    neutron_metadata_proxy_shared_secret => $password,
  }
  class { 'nova::compute':
    enabled                       => true,
    vnc_enabled                   => true,
    #vnc_keymap                    => 'fr-ch',
    vncproxy_host                 => "controller.$domain",
    vncserver_proxyclient_address => $controllerint,
    #novncproxy_base_url           => "http://controller.$domain:6080/vnc_auto.html",
    #xvpvncproxy_base_url          => "http://controller.$domain:6081/console",
    #vncserver_listen              => $controllerint,
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
  class { '::nova::vncproxy':
    host    => "controller-ext",
    enabled => false, # because compute node
  }
  class { [
    'nova::scheduler',
    'nova::objectstore',
    'nova::cert',
    'nova::consoleauth',
    'nova::conductor'
  ]:
    enabled => false, # because compute node
  }
  class { 'keystone':
    verbose             => true,
    debug               => true,
    database_connection => "mysql://keystone:${password}@${controllerint}/keystone",
    admin_token         => '84833d78d65ef3b009a6',
    admin_bind_host     => $controllerint,
    enabled             => false, # Because we're not the controller TODO create a "common" class
    mysql_module        => 2.2,
  }
##  class { 'keystone::roles::admin':
##    email    => "admin@$domain",
##    password => $password,
##  }
  class { '::neutron':
    verbose               => true,
    debug                 => false,
    enabled               => true,
    bind_host             => 'localhost',
    allow_overlapping_ips => true,
    rabbit_password       => $password,
    rabbit_user           => 'rabbitmq',
    rabbit_host           => "${controllerint}",
    # We're not using aliases because of https://bugs.launchpad.net/ubuntu/+source/neutron/+bug/1304876
    core_plugin           => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins       => ['neutron.services.l3_router.l3_router_plugin.L3RouterPlugin', 'neutron.services.firewall.fwaas_plugin.FirewallPlugin'],
  }
  class { '::neutron::server':
    auth_host      => $controllerint,
    auth_password  => $password,
    sql_connection => "mysql://neutron:${password}@${controllerint}/neutron",
    mysql_module   => 2.2,
    enabled        => false, # because compute node
    sync_db        => false, # because compute node
  }
  class { '::neutron::keystone::auth':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
    tenant           => 'services',
  }
#  class { 'neutron::agents::l3':
#    enabled => false,
#  }
  class { 'neutron::agents::ml2::ovs':
    enable_tunneling => true,
    local_ip         => ${computeint},
    enabled          => true,
    tunnel_types     => [ 'gre' ],
  }
  # ml2 plugin with gre as ml2 driver and ovs as mechanism driver
  class { 'neutron::plugins::ml2':
    type_drivers          => ['flat','gre'],
    tenant_network_types  => ['flat','gre'],
    mechanism_drivers     => ['openvswitch'],
    tunnel_id_ranges      => ['1:1000']
  }
  class { 'neutron::server::notifications':
    nova_admin_tenant_name     => 'services',
    nova_admin_password        => $password,
    nova_url                   => "http://${controllerint}:8774/v2",
    nova_admin_auth_url        => "http://${controllerint}:35357/v2.0",
  }
  file { '/usr/local/bin/stacktail':
    source => "puppet:///modules/cleverstack/stacktail",
    ensure => file,
    owner  => root,
    group  => root,
    mode   => 0755,
  }
}
