# headscale's settings, shared by the host aspect (services/networking/headscale.nix)
# and the cluster's pod (kubernetes/services/network/headscale.nix), so both render
# one control plane. The caller supplies what differs by where it runs: the DERP
# region code and the OIDC secret path, and the policy file's path.
{ lib }:
let
  resolvers = import ../../core/network/_resolvers.nix { inherit lib; };
in
{
  # The ACL policy: everything may reach everything, and each host's exit node is
  # auto-approved (it joins as its own user, tailscale/secrets.nix).
  policy = exit-nodes: {
    acls = [
      {
        action = "accept";
        src = [ "*" ];
        dst = [ "*:*" ];
      }
    ];
    autoApprovers.exitNode = map (n: "${n.hostname}@") exit-nodes;
  };

  settings =
    {
      environment,
      dns-resolvers,
      regionCode,
      oidcSecretPath,
      policyPath,
    }:
    {
      server_url = "https://${environment.getDomainFor "headscale"}";
      logtail = {
        enabled = false;
      };
      prefixes = {
        v4 = "100.72.0.0/16";
        v6 = "fd7a:115c:a1e0::/48";
        allocation = "random";
      };
      derp = {
        server = {
          enabled = true;
          region_id = 999;
          region_code = regionCode;
          region_name = regionCode + " DERP";
          stun_listen_addr = "0.0.0.0:3478";
          auto_update_enabled = true;
          automatically_add_embedded_derp_region = true;
        };
      };

      dns = {
        magic_dns = true;
        base_domain = "ts.${environment.domain}";
        override_local_dns = true;
        # Roaming devices (docs/dns-resolver.md §2.4c): the filtering resolvers
        # without the gateway (private, so tailscaled would race it at once, and
        # unreachable off the LAN), then the environment's upstreams, which
        # tailscaled upgrades to DoH, so off-LAN clients and an outage keep DNS.
        nameservers.global =
          lib.optionals (environment.dns.roamingResolvers != [ ]) (
            resolvers.resolversFor {
              gateway = false;
              list = "roamingResolvers";
            } environment dns-resolvers
          )
          ++ resolvers.plainUpstreams environment;
      };

      oidc = {
        only_start_if_oidc_is_available = true;
        issuer = "https://${environment.getDomainFor "kanidm"}/oauth2/openid/headscale";
        client_id = "headscale";
        client_secret_path = oidcSecretPath;
        scope = [
          "openid"
          "profile"
          "email"
        ];
        pkce = {
          enabled = true;
          method = "S256";
        };
      };

      policy.path = policyPath;
    };
}
