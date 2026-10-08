# Domain aspects, composed in den.domains.<fqdn>.includes
# (modules/den/domains/domains.nix). Each emits quirks from the domain entity;
# consumers take them as function arguments (routing: policies/pipes.nix).
#
#   dns.cloudflare <account>   dns-zones            the zone is a Cloudflare zone
#   dns.records [ ... ]        dns-records          records stated on the zone
#   tls.dns01 <issuer>         certificate-domains  wildcard cert + gateway listeners
#   web.apex                   apex-domains, dns-records (apex, www)
#   web.landing                web.apex + site-domains (Garage website bucket)
#   pages.github { ... }       dns-records          GitHub Pages at the apex
#   mail.protonmail { ... }    dns-records          Proton Mail
#
# A record name is relative to the domain ("@" = the domain itself). Fields:
# { name; type; content ? null; proxied ? false; priority ? null; ttl ? 1;
# comment ? null; }, where a null content is the edge's public IPv4.
{ lib, ... }:
let
  # A parametric aspect for one domain; the name keeps two domains' instances
  # of the same aspect distinct.
  forDomain =
    tag: f:
    { domain, ... }:
    {
      name = "${tag}@${domain.name}";
    }
    // f domain;

  records =
    tag: rs:
    forDomain tag (domain: {
      dns-records = map (
        r: r // { name = if r.name == "@" then domain.name else "${r.name}.${domain.name}"; }
      ) rs;
    });

  quote = s: "\"${s}\"";

  apex = forDomain "web.apex" (domain: {
    apex-domains.domain = domain.name;
    dns-records =
      map
        (name: {
          inherit name;
          type = "A";
          proxied = true;
        })
        [
          domain.name
          "www.${domain.name}"
        ];
  });
in
{
  den.aspects.domain = {
    dns = {
      # A domain without this is hosted in its nearest managed ancestor
      # (dev.json64.dev in json64.dev); with it, it is a zone of its own.
      cloudflare =
        account:
        forDomain "dns.cloudflare" (domain: {
          dns-zones = {
            zone = domain.name;
            inherit account;
          };
        });

      records = records "dns.records";
    };

    tls.dns01 =
      arg:
      let
        a = if builtins.isString arg then { issuer = arg; } else arg;
      in
      forDomain "tls.dns01" (domain: {
        certificate-domains = {
          domain = domain.name;
          inherit (a) issuer;
          # The k8s resource-name stem, when the last-two-labels default would
          # collide with a parent (s3.json64.dev -> json64-dev).
          resourceName = a.resourceName or null;
        };
      });

    web = {
      # The edge gateway serves the bare domain (an apex listener) and its www.
      inherit apex;

      landing = {
        name = "web.landing";
        includes = [
          apex
          (forDomain "web.landing" (domain: {
            site-domains.domain = domain.name;
          }))
        ];
      };
    };

    pages.github =
      {
        user,
        verification ? null,
      }:
      records "pages.github" (
        map (content: {
          name = "@";
          type = "A";
          inherit content;
        }) (map (n: "185.199.${toString n}.153") (lib.range 108 111))
        ++ map (content: {
          name = "@";
          type = "AAAA";
          inherit content;
        }) (map (n: "2606:50c0:800${toString n}::153") (lib.range 0 3))
        ++ [
          {
            name = "www";
            type = "CNAME";
            content = "${user}.github.io";
          }
        ]
        ++ lib.optional (verification != null) {
          name = "_github-pages-challenge-${user}";
          type = "TXT";
          content = verification;
        }
      );

    mail.protonmail =
      {
        verification,
        dkimDomain,
        dmarc,
      }:
      records "mail.protonmail" (
        [
          {
            name = "@";
            type = "MX";
            content = "mail.protonmail.ch";
            priority = 10;
          }
          {
            name = "@";
            type = "MX";
            content = "mailsec.protonmail.ch";
            priority = 20;
          }
          {
            name = "@";
            type = "TXT";
            content = quote "v=spf1 include:_spf.protonmail.ch ~all";
          }
          {
            name = "@";
            type = "TXT";
            content = quote "protonmail-verification=${verification}";
          }
          {
            name = "_dmarc";
            type = "TXT";
            content = quote "v=DMARC1; ${dmarc}";
          }
        ]
        ++
          map
            (k: {
              name = "${k}._domainkey";
              type = "CNAME";
              content = "${k}.domainkey.${dkimDomain}";
            })
            (
              map (s: "protonmail${s}") [
                ""
                "2"
                "3"
              ]
            )
      );
  };
}
