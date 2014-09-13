class cleverstack::bind(
  $forwarders = '',
) {
  # Bind configuration
  # The instance has these lines in its /etc/resolv.conf file:
  # search yourdomain.com
  # nameserver 192.168.42.2
  # The domain packets travel through the qdhcp namespace to the dnsmasq instance on 192.168.42.2.
  # In a normal environment, dnsmasq would be able to forward the request to the DNS server on the Internet.
  # Since we have an additional fake public network, we need to install a DNS server on 10.88.15.1 that is
  # accessible by dnsmasq and that will in turn forward the domain requests to the real public DNS servers.
  class { '::bind': }
  ::bind::server::conf { '/etc/named.conf':
    listen_on_addr => [ '10.88.15.1' ],
    allow_query    => [ ],
    forwarders     => $forwarders,
  }
}
