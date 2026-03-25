{ lib, ... }:
{
  features.bgp = {
    settings = {
      localAsn = lib.mkOption {
        type = lib.types.int;
        default = 65001;
        description = "Local BGP AS number for this node";
      };
    };

    linux =
      {
        lib,
        config,
        host,
        settings,
        ...
      }:
      let
        cfg = config.services.bgp;
        localAsn = settings.bgp.localAsn;
        routerId = builtins.head host.ipv4;
      in
      {
        options.services.bgp = {
          staticRoutes = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Static IP routes";
          };

          prefixLists = lib.mkOption {
            type = lib.types.attrsOf (lib.types.listOf lib.types.str);
            default = { };
            description = "IP prefix lists";
          };

          routeMaps = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [ ];
            description = "Route map configurations";
          };

          neighbors = lib.mkOption {
            type = lib.types.listOf (
              lib.types.submodule {
                options = {
                  ip = lib.mkOption {
                    type = lib.types.str;
                    description = "Neighbor IP address";
                  };
                  asn = lib.mkOption {
                    type = lib.types.int;
                    description = "Neighbor AS number";
                  };
                  updateSource = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Update source interface";
                  };
                  ebgpMultihop = lib.mkOption {
                    type = lib.types.nullOr lib.types.int;
                    default = null;
                    description = "EBGP multihop distance";
                  };
                  softReconfiguration = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable soft reconfiguration inbound";
                  };
                  routeMapIn = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Inbound route map";
                  };
                  routeMapOut = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Outbound route map";
                  };
                  allowasIn = lib.mkOption {
                    type = lib.types.nullOr lib.types.int;
                    default = null;
                    description = "Allow AS in path";
                  };
                };
              }
            );
            default = [ ];
            description = "BGP neighbors";
          };

          peerGroups = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  remoteAs = lib.mkOption {
                    type = lib.types.int;
                    description = "Remote AS for peer group";
                  };
                  updateSource = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "Update source interface";
                  };
                  ebgpMultihop = lib.mkOption {
                    type = lib.types.nullOr lib.types.int;
                    default = null;
                    description = "EBGP multihop distance";
                  };
                  softReconfiguration = lib.mkOption {
                    type = lib.types.bool;
                    default = false;
                    description = "Enable soft reconfiguration inbound";
                  };
                  listenRange = lib.mkOption {
                    type = lib.types.nullOr lib.types.str;
                    default = null;
                    description = "BGP listen range for peer group";
                  };
                };
              }
            );
            default = { };
            description = "BGP peer groups";
          };

          addressFamilies = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule {
                options = {
                  networks = lib.mkOption {
                    type = lib.types.listOf lib.types.str;
                    default = [ ];
                    description = "Networks to advertise";
                  };
                  neighbors = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        options = {
                          activate = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Activate neighbor for this address family";
                          };
                          nextHopSelf = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Set next-hop-self for neighbor";
                          };
                          defaultOriginate = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Send default route to this neighbor";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Per-neighbor address family settings";
                  };
                  peerGroups = lib.mkOption {
                    type = lib.types.attrsOf (
                      lib.types.submodule {
                        options = {
                          activate = lib.mkOption {
                            type = lib.types.bool;
                            default = true;
                            description = "Activate peer group for this address family";
                          };
                          nextHopSelf = lib.mkOption {
                            type = lib.types.bool;
                            default = false;
                            description = "Set next-hop-self for peer group";
                          };
                        };
                      }
                    );
                    default = { };
                    description = "Per-peer-group address family settings";
                  };
                };
              }
            );
            default = { };
            description = "BGP address family configurations";
          };

          maximumPaths = lib.mkOption {
            type = lib.types.int;
            default = 8;
            description = "Maximum number of BGP paths";
          };

          extraConfig = lib.mkOption {
            type = lib.types.str;
            default = "";
            description = "Extra BGP configuration";
          };
        };

        config =
          let
            # Build config lines as lists, then join — avoids nested multiline string indentation issues
            ind = "  "; # FRR indentation

            staticRouteLines = lib.optionals (cfg.staticRoutes != [ ]) (
              [ "! Static routes" ] ++ cfg.staticRoutes ++ [ "!" ]
            );

            prefixListLines = lib.optionals (cfg.prefixLists != { }) (
              [ "! Prefix lists" ]
              ++ lib.flatten (
                lib.mapAttrsToList (
                  name: entries:
                  lib.imap0 (i: entry: "ip prefix-list ${name} seq ${toString ((i + 1) * 10)} ${entry}") entries
                ) cfg.prefixLists
              )
              ++ [ "!" ]
            );

            routeMapLines = lib.optionals (cfg.routeMaps != [ ]) (
              [ "! Route maps" ] ++ cfg.routeMaps ++ [ "!" ]
            );

            mkPeerGroupLines =
              name: group:
              [
                "${ind}neighbor ${name} peer-group"
                "${ind}neighbor ${name} remote-as ${toString group.remoteAs}"
              ]
              ++ lib.optional group.softReconfiguration "${ind}neighbor ${name} soft-reconfiguration inbound"
              ++ lib.optional (
                group.updateSource != null
              ) "${ind}neighbor ${name} update-source ${group.updateSource}"
              ++ lib.optional (
                group.ebgpMultihop != null
              ) "${ind}neighbor ${name} ebgp-multihop ${toString group.ebgpMultihop}"
              ++ lib.optional (
                group.listenRange != null
              ) "${ind}bgp listen range ${group.listenRange} peer-group ${name}";

            peerGroupLines = lib.optionals (cfg.peerGroups != { }) (
              [ "${ind}!" ] ++ lib.flatten (lib.mapAttrsToList mkPeerGroupLines cfg.peerGroups)
            );

            mkNeighborLines =
              neighbor:
              [ "${ind}neighbor ${neighbor.ip} remote-as ${toString neighbor.asn}" ]
              ++ lib.optional neighbor.softReconfiguration "${ind}neighbor ${neighbor.ip} soft-reconfiguration inbound"
              ++ lib.optional (
                neighbor.updateSource != null
              ) "${ind}neighbor ${neighbor.ip} update-source ${neighbor.updateSource}"
              ++ lib.optional (
                neighbor.ebgpMultihop != null
              ) "${ind}neighbor ${neighbor.ip} ebgp-multihop ${toString neighbor.ebgpMultihop}"
              ++ lib.optional (
                neighbor.routeMapIn != null
              ) "${ind}neighbor ${neighbor.ip} route-map ${neighbor.routeMapIn} in"
              ++ lib.optional (
                neighbor.routeMapOut != null
              ) "${ind}neighbor ${neighbor.ip} route-map ${neighbor.routeMapOut} out"
              ++ lib.optional (
                neighbor.allowasIn != null
              ) "${ind}neighbor ${neighbor.ip} allowas-in ${toString neighbor.allowasIn}";

            neighborLines = lib.optionals (cfg.neighbors != [ ]) (
              [ "${ind}!" ] ++ lib.flatten (map mkNeighborLines cfg.neighbors)
            );

            mkAddressFamilyLines =
              family: familyConfig:
              let
                familyName = lib.replaceStrings [ "-" ] [ " " ] family;
                networkLines = map (net: "${ind}${ind}network ${net}") familyConfig.networks;
                neighLines = lib.filter (s: s != "") (
                  lib.flatten (
                    lib.mapAttrsToList (
                      ip: nc:
                      lib.optional nc.activate "${ind}${ind}neighbor ${ip} activate"
                      ++ lib.optional nc.nextHopSelf "${ind}${ind}neighbor ${ip} next-hop-self"
                      ++ lib.optional nc.defaultOriginate "${ind}${ind}neighbor ${ip} default-originate"
                    ) familyConfig.neighbors
                  )
                );
                peerGroupAfLines = lib.flatten (
                  lib.mapAttrsToList (
                    name: gc:
                    lib.optional gc.activate "${ind}${ind}neighbor ${name} activate"
                    ++ lib.optional gc.nextHopSelf "${ind}${ind}neighbor ${name} next-hop-self"
                  ) familyConfig.peerGroups
                );
              in
              [
                "${ind}!"
                "${ind}address-family ${familyName}"
              ]
              ++ networkLines
              ++ neighLines
              ++ peerGroupAfLines
              ++ [ "${ind}exit-address-family" ];

            addressFamilyLines = lib.optionals (cfg.addressFamilies != { }) (
              lib.flatten (lib.mapAttrsToList mkAddressFamilyLines cfg.addressFamilies)
            );

            bgpLines = [
              "!"
              "router bgp ${toString localAsn}"
              "${ind}bgp router-id ${routerId}"
              "${ind}no bgp ebgp-requires-policy"
              "${ind}bgp bestpath as-path multipath-relax"
              "${ind}maximum-paths ${toString cfg.maximumPaths}"
              "${ind}bgp allow-martian-nexthop"
            ]
            ++ peerGroupLines
            ++ neighborLines
            ++ addressFamilyLines;

            allLines = [
              "ip forwarding"
              "!"
            ]
            ++ staticRouteLines
            ++ prefixListLines
            ++ routeMapLines
            ++ bgpLines
            ++ lib.optional (cfg.extraConfig != "") cfg.extraConfig;
          in
          {
            services.frr.bgpd.enable = true;
            services.frr.config = lib.mkAfter (lib.concatStringsSep "\n" allLines);
          };
      };
  };
}
