# SMTP relay — Postfix (boky/postfix) smarthosting to an upstream submission
# service for LAN and in-cluster senders. Identity and upstream are settings
# with no defaults: a cluster that includes the aspect states them.
#
# Clients submit on 587 with mandatory STARTTLS (a cert for settings.hostname)
# and no auth: the image's restrictions only accept mynetworks, narrowed below
# to RFC1918, and the CNP narrows ingress further to 10.0.0.0/8. Outbound is a
# verified-TLS SASL login as settings.upstream.username.
#
# Providers such as Proton only accept mail from the token's own address, so
# the envelope sender is canonicalised to it and the From header address is
# rewritten by header_checks, keeping the display name. A canonical map on
# header_sender would also clobber Reply-To, hence the split.
# ALLOWED_SENDER_DOMAINS checks the pre-rewrite envelope, so clients must
# still send from settings.domain.
#
# The hostname needs a DNS record on the private LB IP (domains/domains.nix):
# kanidm-mail-sender verifies the certificate name, so clients need a name.
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  den.aspects.kubernetes.services.communication.smtp-relay = {
    settings = {
      domain = mkOption {
        type = types.str;
        example = "example.com";
        description = ''
          Sender domain. Clients must submit with an envelope sender in this
          domain (ALLOWED_SENDER_DOMAINS).
        '';
      };

      hostname = mkOption {
        type = types.str;
        example = "smtp.example.com";
        description = ''
          Name the relay presents (myhostname) and its STARTTLS certificate is
          issued for. Must resolve to the relay's LoadBalancer address.
        '';
      };

      issuer = mkOption {
        type = types.str;
        example = "example-com";
        description = ''
          cert-manager issuer stem; the certificate is requested from the
          `<issuer>-issuer` ClusterIssuer.
        '';
      };

      upstream = {
        host = mkOption {
          type = types.str;
          example = "smtp.example.com";
          description = "Upstream submission host the relay smarthosts to.";
        };

        port = mkOption {
          type = types.port;
          default = 587;
          description = "Upstream submission port (STARTTLS, verified).";
        };

        username = mkOption {
          type = types.str;
          example = "infra@example.com";
          description = ''
            Upstream SASL login. Also the address every sender is rewritten to,
            envelope and From header, since providers such as Proton only
            accept mail from the token's own address.
          '';
        };

        passwordSecret = mkOption {
          type = types.str;
          example = "smtp-infra-at-example-com.age";
          description = ''
            Age file holding the upstream password or token, relative to the
            environment's secretPath. Supplied by hand; no generator.
          '';
        };
      };
    };

    service-domains = [ ];

    age-secrets =
      { cluster, environment, ... }:
      {
        age.secrets.smtp-relay-upstream-password = {
          rekeyFile =
            environment.secretPath
            + "/${cluster.settings.kubernetes.services.communication.smtp-relay.upstream.passwordSecret}";
          sopsOutput = {
            file = "smtp";
            key = "upstream-password";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        ...
      }:
      let
        s = cluster.settings.kubernetes.services.communication.smtp-relay;
        # Inline regexp table; $$ escapes main.cf macro expansion.
        fromRewrite = "regexp:{ {/^From:[[:space:]]*(.*[^[:space:]])[[:space:]]*<[^>]*>[[:space:]]*$$/ REPLACE From: $$1 <${s.upstream.username}>}, {/^From:[[:space:]]*[^<]*$$/ REPLACE From: ${s.upstream.username}} }";
      in
      {
        applications.smtp-relay = {
          namespace = "mail";

          helm.releases.smtp-relay = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              # The image applies every POSTFIX_* variable as a postconf
              # setting; service links would inject Kubernetes ones.
              defaultPodOptions.enableServiceLinks = false;

              controllers.main = {
                type = "deployment";
                # One instance: a second would hold a separate queue.
                strategy = "Recreate";
                containers.main = {
                  image = {
                    inherit (images."boky/postfix") repository digest;
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    LOG_FORMAT = "json";
                    POSTFIX_myhostname = s.hostname;
                    POSTFIX_mynetworks = "127.0.0.0/8,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16";
                    ALLOWED_SENDER_DOMAINS = s.domain;
                    POSTFIX_message_size_limit = "26214400";

                    RELAYHOST = "[${s.upstream.host}]:${toString s.upstream.port}";
                    RELAYHOST_USERNAME = s.upstream.username;
                    RELAYHOST_PASSWORD.valueFrom.secretKeyRef = {
                      name = "smtp-relay-upstream";
                      key = "password";
                    };
                    POSTFIX_smtp_tls_security_level = "secure";

                    POSTFIX_smtpd_tls_security_level = "encrypt";
                    POSTFIX_smtpd_tls_cert_file = "/tls/tls.crt";
                    POSTFIX_smtpd_tls_key_file = "/tls/tls.key";

                    POSTFIX_sender_canonical_maps = "static:${s.upstream.username}";
                    POSTFIX_sender_canonical_classes = "envelope_sender";
                    POSTFIX_header_checks = fromRewrite;
                  };
                };
              };

              service.main = {
                controller = "main";
                type = "LoadBalancer";
                externalTrafficPolicy = "Local";
                annotations."lbipam.cilium.io/ips" = cluster.getAssignment "smtp-relay-internal";
                ports.submission.port = 587;
              };

              persistence = {
                tls = {
                  type = "secret";
                  name = "smtp-relay-tls";
                  globalMounts = [
                    {
                      path = "/tls";
                      readOnly = true;
                    }
                  ];
                };
                spool = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "1Gi";
                  storageClass = "longhorn";
                  globalMounts = [ { path = "/var/spool/postfix"; } ];
                };
              };
            };
          };

          resources = {
            secrets.smtp-relay-upstream.stringData.password =
              config.age.secrets.smtp-relay-upstream-password.sopsRef;

            certificates.smtp-relay.spec = {
              secretName = "smtp-relay-tls";
              issuerRef = {
                name = "${s.issuer}-issuer";
                kind = "ClusterIssuer";
              };
              dnsNames = [ s.hostname ];
            };

            ciliumNetworkPolicies = {
              allow-submission-ingress-smtp-relay.spec = {
                description = "Allow private-network clients to submit mail to the relay.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "smtp-relay";
                ingress = [
                  {
                    fromCIDR = [ "10.0.0.0/8" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "587";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                  {
                    fromEntities = [ "cluster" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "587";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-dns-egress-smtp-relay.spec = {
                description = "Allow smtp-relay to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "smtp-relay";
                egress = [
                  {
                    toEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "kube-system";
                          "k8s-app" = "kube-dns";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          {
                            port = "53";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              allow-upstream-egress-smtp-relay.spec = {
                description = "Allow smtp-relay to submit to its upstream.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "smtp-relay";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = toString s.upstream.port;
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}
