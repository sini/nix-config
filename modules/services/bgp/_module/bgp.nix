{
  lib,
  config,
  ...
}:
let
  cfg = config.services.bgp;
in
{
  options.services.bgp = {
    localAsn = lib.mkOption {
      type = lib.types.int;
      description = "Local AS number for BGP";
    };

    routerId = lib.mkOption {
      type = lib.types.str;
      description = "BGP router ID (IP address)";
    };

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

  config = {
    services.frr.bgpd.enable = true;
    services.frr.config = lib.mkAfter ''
      ip forwarding
      !
      ${lib.optionalString (cfg.staticRoutes != [ ]) ''
        ! Static routes
        ${lib.concatStringsSep "\n" cfg.staticRoutes}
        !
      ''}
      ${lib.optionalString (cfg.prefixLists != { }) ''
        ! Prefix lists
        ${lib.concatStringsSep "\n" (
          lib.flatten (
            lib.mapAttrsToList (
              name: entries:
              lib.imap0 (i: entry: "ip prefix-list ${name} seq ${toString ((i + 1) * 10)} ${entry}") entries
            ) cfg.prefixLists
          )
        )}
        !
      ''}
      ${lib.optionalString (cfg.routeMaps != [ ]) ''
        ! Route maps
        ${lib.concatStringsSep "\n" cfg.routeMaps}
        !
      ''}
      ! BGP configuration
      router bgp ${toString cfg.localAsn}
        bgp router-id ${cfg.routerId}
        no bgp ebgp-requires-policy
        bgp bestpath as-path multipath-relax
        maximum-paths ${toString cfg.maximumPaths}
        bgp allow-martian-nexthop
        !
        ${lib.optionalString (cfg.peerGroups != { }) ''
          ! Peer group definitions
          ${lib.concatStringsSep "\n  " (
            lib.mapAttrsToList (name: group: ''
              ! GROUP ${name}
              neighbor ${name} peer-group
              neighbor ${name} remote-as ${toString group.remoteAs}
              ${lib.optionalString group.softReconfiguration "neighbor ${name} soft-reconfiguration inbound"}
              ${lib.optionalString (
                group.updateSource != null
              ) "neighbor ${name} update-source ${group.updateSource}"}
              ${lib.optionalString (
                group.ebgpMultihop != null
              ) "neighbor ${name} ebgp-multihop ${toString group.ebgpMultihop}"}
              ${lib.optionalString (
                group.listenRange != null
              ) "bgp listen range ${group.listenRange} peer-group ${name}"}
            '') cfg.peerGroups
          )}
        ''}
        ${lib.optionalString (cfg.neighbors != [ ]) ''
          ! Neighbor definitions
            ${lib.concatMapStringsSep "\n  " (
              neighbor:
              "neighbor ${neighbor.ip} remote-as ${toString neighbor.asn}"
              + lib.optionalString neighbor.softReconfiguration "\n  neighbor ${neighbor.ip} soft-reconfiguration inbound"
              + lib.optionalString (
                neighbor.updateSource != null
              ) "\n  neighbor ${neighbor.ip} update-source ${neighbor.updateSource}"
              + lib.optionalString (
                neighbor.ebgpMultihop != null
              ) "\n  neighbor ${neighbor.ip} ebgp-multihop ${toString neighbor.ebgpMultihop}"
              + lib.optionalString (
                neighbor.routeMapIn != null
              ) "\n  neighbor ${neighbor.ip} route-map ${neighbor.routeMapIn} in"
              + lib.optionalString (
                neighbor.allowasIn != null
              ) "\n  neighbor ${neighbor.ip} allowas-in ${toString neighbor.allowasIn}"
            ) cfg.neighbors}
            !
        ''}
        ${
          lib.optionalString (cfg.addressFamilies != { }) ''
            ${lib.concatStringsSep "\n" (
              lib.mapAttrsToList (family: familyConfig: ''
                ! Address Family ${family}
                  address-family ${lib.replaceStrings [ "-" ] [ " " ] family}
                    ${lib.concatStringsSep "\n    " (map (net: "network ${net}") familyConfig.networks)}
                    ${lib.concatStringsSep "\n    " (
                      lib.filter (s: s != "") (
                        lib.flatten (
                          lib.mapAttrsToList (ip: neighConfig: [
                            (lib.optionalString neighConfig.activate "neighbor ${ip} activate")
                            (lib.optionalString neighConfig.nextHopSelf "neighbor ${ip} next-hop-self")
                            (lib.optionalString neighConfig.defaultOriginate "neighbor ${ip} default-originate")
                          ]) familyConfig.neighbors
                        )
                      )
                    )}
                    ${lib.concatStringsSep "\n" (
                      lib.mapAttrsToList (
                        name: groupConfig:
                        lib.optionalString groupConfig.activate "neighbor ${name} activate"
                        + lib.optionalString groupConfig.nextHopSelf "\n    neighbor ${name} next-hop-self"
                      ) familyConfig.peerGroups
                    )}
                  exit-address-family
              '') cfg.addressFamilies
            )}
          ''
        }${cfg.extraConfig}
    '';
  };
}
