{
  # BGP spoke is a marker feature used for BGP hub auto-discovery
  # It doesn't enable any specific configuration, but identifies hosts
  # that should be discovered by bgp-hub as BGP peers
  features.bgp-spoke = {
    requires = [ ];
  };
}
