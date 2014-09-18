node /controller/ {
  Package { allow_virtual => false, }
  class { 'cleverstack':
    controllerint => 'controller-int',
    password      => '###PASSWORD###',
  } ->
  class { 'cleverstack::controller':
    controllerext => 'controller-ext',
    controllerint => 'controller-int',
    computeint    => 'compute-int',
    password      => '###PASSWORD###',
    cinderpv      => '###CINDERPV###',
    domain        => '###DOMAIN###',
    forwarders    => [ '###FORWARDER###' ],
    require => Class['cleverstack'],
  }
}

node /compute1/ {
  Package { allow_virtual => false, }
  class { 'cleverstack':
    controllerint => 'controller-int',
    password      => '###PASSWORD###',
  } ->
  class { 'cleverstack::compute':
    computeext    => 'compute-ext',
    computeint    => 'compute-int',
    controllerext => 'controller-ext',
    controllerint => 'controller-int',
    password      => '###PASSWORD###',
    domain        => '###DOMAIN###',
  }
}
