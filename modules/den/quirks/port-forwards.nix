{
  den.quirks.port-forwards.description = ''Gateway port forwards ({ environment; name; protocol; wanPort; forward = { ip; port; }; allWans ? false; mode ? "forward"; }), emitted by the aspect that owns the public port and rendered by the environment's UniFi workspace; ports are the controller's strings ("443", "3478,41641"). mode "forward" is a UniFi port forward; "nat" is custom NAT rules (DNAT on the WAN and on each hairpin LAN, masquerade for hairpin clients only), one port, allWans unused'';
}
