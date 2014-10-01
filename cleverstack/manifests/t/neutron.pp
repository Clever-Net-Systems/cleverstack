class cleverstack::neutron(
  $password        = '',
  $controllerint   = '',
  $ipcontrollerint = '',
  $computeint      = '',
  $domain          = '',
) {
  class { '::neutron':
    verbose               => true,
    debug                 => false,
    enabled               => true,
    bind_host             => '0.0.0.0',
    allow_overlapping_ips => true,
    rabbit_password       => $password,
    rabbit_user           => 'rabbitmq',
    rabbit_host           => $controllerint,
    # We're not using aliases because of https://bugs.launchpad.net/ubuntu/+source/neutron/+bug/1304876
    core_plugin           => 'neutron.plugins.ml2.plugin.Ml2Plugin',
    service_plugins       => ['neutron.services.l3_router.l3_router_plugin.L3RouterPlugin', 'neutron.services.firewall.fwaas_plugin.FirewallPlugin', 'neutron.services.loadbalancer.plugin.LoadBalancerPlugin'],
  }
  class { '::neutron::server':
    auth_host      => $controllerint,
    auth_password  => $password,
    sql_connection => "mysql://neutron:${password}@${controllerint}/neutron",
    mysql_module   => 2.2,
  }
  class { "::neutron::db::mysql":
    user          => 'neutron',
    password      => $password,
    dbname        => 'neutron',
    allowed_hosts => [ "%.$domain", $computeint ],
    mysql_module  => 2.2,
  }
  class { '::neutron::keystone::auth':
    password         => $password,
    public_address   => $controllerint,
    admin_address    => $controllerint,
    internal_address => $controllerint,
    region           => 'RegionOne',
    tenant           => 'services',
  }
  class { 'neutron::agents::dhcp': }
  # In a normal setup, we wouldn't need this but since we're using a fake external subnet, we need to proxy DNS requests.
  # See further below for the installation of the named daemon.
  neutron_dhcp_agent_config {
    'DEFAULT/dhcp_domain':         value => "$domain";
    'DEFAULT/dnsmasq_dns_servers': value => '10.88.15.1';
  }
  class { 'neutron::agents::l3':
#    external_network_bridge => '';
  }
  neutron_l3_agent_config { 'DEFAULT/ovs_use_veth':
    value => True;
  }
  class { 'neutron::agents::lbaas':
    user_group => 'nobody',
    enabled => true,
  }
  class { 'neutron::agents::vpnaas':
    enabled => false,
  }
  class { 'neutron::agents::metering':
    enabled => false,
  }
  class { 'neutron::services::fwaas':
    enabled => true,
  }
  class { 'neutron::agents::metadata':
    auth_password => $password,
    shared_secret => $password,
    auth_url      => "http://${controllerint}:35357/v2.0",
    debug         => True,
    auth_region   => 'RegionOne',
    metadata_ip   => $controllerint,
    enabled       => true,
  }
  class { 'neutron::agents::ml2::ovs':
    enable_tunneling => true,
    local_ip => $ipcontrollerint,
    enabled => true,
    tunnel_types => [ 'gre' ],
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
}
