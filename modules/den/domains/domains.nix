# Domains: zones and sub-zones as den entities, composed from the domain
# aspects (modules/den/aspects/domain/domain.nix). Public DNS:
# modules/flake-parts/terranix, infra/dns/README.md.
{ den, ... }:
let
  inherit (den.aspects.domain)
    dns
    tls
    web
    pages
    mail
    ;

  cloudflare = dns.cloudflare "json64";

  # A Cloudflare zone with its own landing page (garage/sites.nix).
  landing = {
    includes = [
      cloudflare
      (tls.dns01 "global")
      web.landing
    ];
  };

  # Certificates only; DNS for these zones is not managed here.
  certsOnly = {
    includes = [ (tls.dns01 "global") ];
  };
in
{
  den.domains = {
    "json64.dev".includes = [
      cloudflare
      (tls.dns01 "json64-dev")
      # The apex serves json64.dev/.well-known/matrix/* (Matrix delegation for
      # server_name json64.dev; communication/matrix/synapse.nix).
      web.apex
      (mail.protonmail {
        verification = "af5115ee2fefd384e38c3271eaf24788fc7e3b3c";
        dkimDomain = "d6mzv4vscxbsx7a4d3tpxp73nx2ue5kali46oa7h5xdcq37ngo4oq.domains.proton.ch";
        dmarc = "p=quarantine";
      })
      (dns.records [
        # Grey CNAMEs to the apex, as live; they take precedence over the A
        # records headscale and jellyfin's served names would derive.
        {
          name = "hs";
          type = "CNAME";
          content = "json64.dev";
        }
        {
          name = "jellyfin";
          type = "CNAME";
          content = "json64.dev";
        }
        # Shared public IP for ssh and some tailscale users (grey-cloud: not HTTP).
        {
          name = "vpn";
          type = "A";
        }
        # The cluster's private SMTP relay LB (communication/smtp-relay.nix):
        # public so any LAN client can verify its certificate by name.
        {
          name = "smtp";
          type = "A";
          content = "10.11.0.30";
        }
        # The cluster's monitoring ingest LB (monitoring/ingest.nix).
        {
          name = "ingest";
          type = "A";
          content = "10.11.0.31";
        }
      ])
    ];

    # Sub-zone with no dns.cloudflare of its own: its records are hosted in the
    # json64.dev zone.
    "dev.json64.dev" = { };

    "s3.json64.dev".includes = [
      # Distinct stem: the last-two-labels default (json64-dev) would collide
      # with the json64.dev wildcard (the *.s3.json64.dev listener and cert).
      (tls.dns01 {
        issuer = "json64-dev";
        resourceName = "s3-json64-dev";
      })
      # S3 vhost-style buckets (garage/routes.nix), grey: proxied mode's 100 MB
      # upload cap breaks S3 multipart. Hosted in the json64.dev zone.
      (dns.records [
        {
          name = "*";
          type = "A";
        }
      ])
    ];

    # The apex is GitHub Pages (sini/gen docs); matrix.gen.wtf is tuwunel.
    "gen.wtf".includes = [
      cloudflare
      (tls.dns01 "global")
      (pages.github {
        user = "sini";
        verification = "976e8aa7ced3167338668254c4f312";
      })
    ];

    "gen-framework.com" = landing;
    "qvr-framework.com" = landing;
    # quiver: candidate project domains.
    "getqvr.com" = landing;
    "quiver-labs.com" = landing;
    "qvrlab.com" = landing;
    "qvr.run" = landing;
    "qvr.sh" = landing;

    "json64.com" = certsOnly;
    "json64.net" = certsOnly;
    "sinistar.io" = certsOnly;
    "sinistar.org" = certsOnly;
    "zeroday.pub" = certsOnly;
    "zeroday.run" = certsOnly;
  };
}
