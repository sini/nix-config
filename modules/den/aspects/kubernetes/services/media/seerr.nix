# Seerr — media request and discovery manager for Jellyfin (the merged
# Overseerr/Jellyseerr, ghcr.io/seerr-team/seerr).
#
# Laid out like the other media apps: a bjw-s app-template release, a longhorn
# config PVC, media-pg for its database, baseline CiliumNetworkPolicies, an
# HTTPRoute on the default-gateway and a Kanidm OIDC SecurityPolicy (media.access).
# Seerr's own sign-in is with Jellyfin accounts, behind the gateway's OIDC.
#
# Postgres via Seerr's DB_* variables, against the single `seerr` database with
# media-pg-seerr-password's credentials. The image runs as `node` (1000:1000), so
# the pod runs as that user with fsGroup 1000 to own the config PVC.
#
# Seerr is configured by the seerr-bootstrap PostSync Job, from `declared` below,
# so a fresh volume needs no hand steps. Read from Seerr 3.5.2's source:
#   - first setup signs in to Jellyfin as an administrator: jellarr's local Admin
#     (jellyfin-secrets), which becomes Seerr's owner (user 1) and makes Seerr its
#     own Jellyfin API key, "Seerr";
#   - afterwards the Job uses Seerr's API key (media-arr-api-keys `seerr`, also
#     Seerr's API_KEY), and converges the Jellyfin, Sonarr, Radarr, login and
#     proxy settings, the libraries, and the users;
#   - sign-in is Jellyfin Quick Connect only: both password logins are off, and
#     Quick Connect creates the Seerr user of any Jellyfin user on first use. The
#     people of media.access are imported up front, and media.admins are Seerr
#     admins.
#
# Its callers and callees: the gateway (ingress, here), media-pg and TMDB (egress,
# here), Jellyfin (egress here; Jellyfin's ingress in jellyfin.nix) and
# Sonarr/Radarr (network-policy.nix edges).
#
# Image tracked via the oci-image-updater at the rolling `latest` tag,
# digest-pinned in images/seerr-team/seerr.
{ config, lib, ... }:
let
  members = import ./_members.nix { inherit config lib; };
  serviceDomains = [ "seerr" ];
  port = 5055;
  uid = 1000;
  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };

  # Profiles and root folders by name; the Job resolves them to ids.
  declared = {
    jellyfin = {
      ip = "jellyfin.media.svc";
      port = 8096;
      useSsl = false;
      urlBase = "";
    };
    main = {
      localLogin = false;
      mediaServerLogin = false;
      newPlexLogin = true;
    };
    network.trustProxy = true;
    sonarr = {
      name = "Sonarr";
      hostname = "sonarr.media.svc";
      port = 8989;
      profile = "1080p Efficient";
      directory = "/data/media/tv";
      animeProfile = "Anime 1080p";
      animeDirectory = "/data/media/anime";
      seriesType = "standard";
      animeSeriesType = "anime";
      enableSeasonFolders = true;
      monitorNewItems = "all";
    };
    radarr = {
      name = "Radarr";
      hostname = "radarr.media.svc";
      port = 7878;
      profile = "1080p Efficient";
      directory = "/data/media/movies";
      minimumAvailability = "released";
    };
    users = {
      import = members "media.access";
      admins = members "media.admins";
    };
  };

  bootstrapScript = ''
    import json, sys, time, urllib.error, urllib.request

    BASE = "http://seerr.media.svc:${toString port}/api/v1"
    NOT_CONFIGURED, JELLYFIN, ADMIN = 4, 2, 2

    with open("/config/declared.json") as f:
        D = json.load(f)


    def secret(name):
        with open(f"/secrets/{name}") as f:
            return f.read().strip()


    KEY = secret("api-key")


    def call(method, path, body=None, key=KEY):
        headers = {"Content-Type": "application/json"}
        if key:
            headers["X-Api-Key"] = key
        data = None if body is None else json.dumps(body).encode()
        req = urllib.request.Request(BASE + path, data=data, headers=headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
                return r.status, json.loads(raw) if raw else None
        except urllib.error.HTTPError as e:
            return e.code, e.read().decode(errors="replace")[:300]


    def ok(status, what):
        if not 200 <= status < 300:
            sys.exit(f"{what}: HTTP {status}")


    for _ in range(90):
        try:
            status, public = call("GET", "/settings/public", key=None)
            if status == 200:
                break
        except OSError:
            pass
        time.sleep(10)
    else:
        sys.exit("Seerr never answered")

    if public["mediaServerType"] == NOT_CONFIGURED:
        j = D["jellyfin"]
        status, body = call("POST", "/auth/jellyfin", {
            "username": "Admin", "password": secret("admin-password"),
            "hostname": j["ip"], "port": j["port"], "useSsl": j["useSsl"],
            "urlBase": j["urlBase"], "email": "admin", "serverType": JELLYFIN,
        }, key=None)
        ok(status, f"first setup as Jellyfin's Admin ({body})")
        print("set up against Jellyfin as Admin")


    def converge(path, want):
        status, have = call("GET", path)
        ok(status, f"GET {path}")
        if any(have.get(k) != v for k, v in want.items()):
            ok(call("POST", path, want)[0], f"POST {path}")
            print(f"updated {path}")


    converge("/settings/jellyfin", {**D["jellyfin"], "externalHostname": D["externalJellyfin"]})
    converge("/settings/main", {**D["main"], "applicationUrl": D["applicationUrl"]})
    converge("/settings/network", D["network"])

    status, libs = call("POST", "/settings/jellyfin/library/sync")
    ok(status, "library sync")
    for lib in libs:
        if not lib["enabled"]:
            ok(call("PUT", f"/settings/jellyfin/library/{lib['id']}", {"enabled": True})[0], "library")
            print(f"enabled library {lib['name']}")


    def dvr(kind, extra):
        d = D[kind]
        conn = {"hostname": d["hostname"], "port": d["port"], "apiKey": secret(kind),
                "useSsl": False, "baseUrl": ""}
        status, test = call("POST", f"/settings/{kind}/test", conn)
        ok(status, f"{kind} test")
        prof = {p["name"]: p["id"] for p in test["profiles"]}
        dirs = {r["path"] for r in test["rootFolders"]}

        def need(name, have):
            if name not in have:
                sys.exit(f"{kind}: no {name!r}; it has {sorted(have)}")
            return name

        want = {**conn, "name": d["name"], "is4k": False, "isDefault": True,
                "activeProfileId": prof[need(d["profile"], prof)],
                "activeProfileName": d["profile"],
                "activeDirectory": need(d["directory"], dirs),
                "tags": [], "syncEnabled": True, "preventSearch": False,
                "tagRequests": False, "externalUrl": D["external"][kind]}
        want.update(extra(d, prof, dirs, need))
        status, have = call("GET", f"/settings/{kind}")
        ok(status, f"GET {kind}")
        mine = [h for h in have if h["name"] == d["name"]]
        if not mine:
            ok(call("POST", f"/settings/{kind}", want)[0], f"add {kind}")
            print(f"added {kind}")
        elif any(mine[0].get(k) != v for k, v in want.items()):
            ok(call("PUT", f"/settings/{kind}/{mine[0]['id']}", {**mine[0], **want})[0], f"update {kind}")
            print(f"updated {kind}")


    dvr("sonarr", lambda d, prof, dirs, need: {
        "activeAnimeProfileId": prof[need(d["animeProfile"], prof)],
        "activeAnimeProfileName": d["animeProfile"],
        "activeAnimeDirectory": need(d["animeDirectory"], dirs),
        "seriesType": d["seriesType"], "animeSeriesType": d["animeSeriesType"],
        "enableSeasonFolders": d["enableSeasonFolders"], "monitorNewItems": d["monitorNewItems"],
    })
    dvr("radarr", lambda d, prof, dirs, need: {"minimumAvailability": d["minimumAvailability"]})

    status, jf = call("GET", "/settings/jellyfin/users")
    ok(status, "Jellyfin users")
    status, users = call("GET", "/user?take=1000")
    ok(status, "Seerr users")
    known = {u.get("jellyfinUserId") for u in users["results"]}
    fresh = [u["id"] for u in jf if u["username"] in D["users"]["import"] and u["id"].replace("-", "") not in {(k or "").replace("-", "") for k in known}]
    if fresh:
        ok(call("POST", "/user/import-from-jellyfin", {"jellyfinUserIds": fresh})[0], "import")
        print(f"imported {len(fresh)} users")
        status, users = call("GET", "/user?take=1000")
        ok(status, "Seerr users")
    promote = [u["id"] for u in users["results"]
               if u["id"] != 1 and u.get("jellyfinUsername") in D["users"]["admins"]
               and not u["permissions"] & ADMIN]
    if promote:
        ok(call("PUT", "/user", {"ids": promote, "permissions": ADMIN})[0], "admins")
        print(f"made {len(promote)} users admin")

    if not public["initialized"]:
        ok(call("POST", "/settings/initialize")[0], "initialize")
        print("initialized")
    print("seerr bootstrap complete")
  '';
in
{
  den.aspects.kubernetes.services.media.seerr = {
    served-domains = { cluster, ... }: cluster.servedDomains serviceDomains;

    age-secrets =
      { environment, ... }:
      {
        age.secrets.seerr-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/seerr-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "seerr";
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
      {
        applications.seerr = {
          namespace = "media";

          helm.releases.seerr = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              defaultPodOptions.securityContext = {
                runAsUser = uid;
                runAsGroup = uid;
                runAsNonRoot = true;
                fsGroup = uid;
                fsGroupChangePolicy = "OnRootMismatch";
              };

              controllers.main = {
                type = "deployment";

                containers.main = {
                  image = {
                    inherit (images."seerr-team/seerr") repository digest;
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PORT = toString port;
                    DB_TYPE = "postgres";
                    DB_HOST = "media-pg-rw";
                    DB_PORT = "5432";
                    DB_NAME = "seerr";
                    DB_USER.valueFrom.secretKeyRef = {
                      name = "media-pg-seerr-password";
                      key = "username";
                    };
                    DB_PASS.valueFrom.secretKeyRef = {
                      name = "media-pg-seerr-password";
                      key = "password";
                    };
                    # Seerr's own API key, which the bootstrap Job calls with.
                    API_KEY.valueFrom.secretKeyRef = {
                      name = "media-arr-api-keys";
                      key = "seerr";
                    };
                  };
                  securityContext = {
                    allowPrivilegeEscalation = false;
                    capabilities.drop = [ "ALL" ];
                  };
                  probes = {
                    liveness.enabled = true;
                    readiness.enabled = true;
                    startup = {
                      enabled = true;
                      # The first start runs the schema migrations.
                      spec.failureThreshold = 60;
                    };
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = port;
              };

              persistence.config = {
                type = "persistentVolumeClaim";
                accessMode = "ReadWriteOnce";
                # settings.json, logs and the image cache.
                size = "5Gi";
                storageClass = "longhorn";
                labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                globalMounts = [ { path = "/app/config"; } ];
              };
            };
          };

          resources = {
            ciliumNetworkPolicies = {
              allow-gateway-ingress-seerr.spec = {
                description = "Allow Envoy Gateway proxies to reach seerr.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                      # The bootstrap Job, against the API.
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "media";
                          "app.kubernetes.io/name" = "seerr-bootstrap";
                        };
                      }
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };

              allow-postgres-egress-seerr.spec = {
                description = "Allow seerr to reach the media-pg CNPG cluster.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."cnpg.io/cluster" = "media-pg"; }
                    ];
                    toPorts = [ { ports = [ (tcp 5432) ]; } ];
                  }
                ];
              };

              # Jellyfin's ingress side admits seerr in jellyfin.nix.
              allow-jellyfin-egress-seerr.spec = {
                description = "Allow seerr to reach jellyfin's API.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                egress = [
                  {
                    toEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "jellyfin"; }
                    ];
                    toPorts = [ { ports = [ (tcp 8096) ]; } ];
                  }
                ];
              };

              # TMDB (metadata and artwork) and the notification agents, all HTTPS.
              allow-internet-egress-seerr.spec = {
                description = "Allow seerr to reach the public internet over HTTPS.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "seerr";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [ { ports = [ (tcp 443) ]; } ];
                  }
                ];
              };
            };

            httpRoutes.seerr.spec = {
              hostnames = [ (cluster.domainFor "seerr") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "seerr"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "seerr";
                      inherit port;
                    }
                  ];
                }
              ];
            };

            securityPolicies."seerr-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "seerr";
                }
              ];
              oidc = {
                provider = cluster.secrets.oidcProviderFor "seerr";
                clientID = "seerr";
                clientSecret.name = "seerr-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                forwardAccessToken = true;
              };
            };

            configMaps.seerr-bootstrap.data = {
              "bootstrap.py" = bootstrapScript;
              "declared.json" = builtins.toJSON (
                declared
                // {
                  applicationUrl = "https://${cluster.domainFor "seerr"}";
                  externalJellyfin = "https://${cluster.domainFor "jellyfin"}";
                  external = {
                    sonarr = "https://${cluster.domainFor "sonarr"}";
                    radarr = "https://${cluster.domainFor "radarr"}";
                  };
                }
              );
            };

            # Converges Seerr's settings after every sync (and so after its first start).
            jobs.seerr-bootstrap = {
              metadata.annotations = {
                "argocd.argoproj.io/hook" = "PostSync";
                "argocd.argoproj.io/hook-delete-policy" = "BeforeHookCreation";
              };
              spec = {
                backoffLimit = 6;
                template = {
                  metadata.labels."app.kubernetes.io/name" = "seerr-bootstrap";
                  spec = {
                    restartPolicy = "OnFailure";
                    automountServiceAccountToken = false;
                    enableServiceLinks = false;
                    # The Secrets' files are root-owned; fsGroup makes them readable (0440).
                    securityContext = {
                      runAsNonRoot = true;
                      runAsUser = 65534;
                      runAsGroup = 65534;
                      fsGroup = 65534;
                      seccompProfile.type = "RuntimeDefault";
                    };
                    containers = [
                      {
                        name = "bootstrap";
                        image = "${images."library/python".repository}@${images."library/python".digest}";
                        command = [
                          "python3"
                          "/config/bootstrap.py"
                        ];
                        securityContext = {
                          allowPrivilegeEscalation = false;
                          readOnlyRootFilesystem = true;
                          capabilities.drop = [ "ALL" ];
                        };
                        volumeMounts = [
                          {
                            name = "config";
                            mountPath = "/config";
                            readOnly = true;
                          }
                          {
                            name = "secrets";
                            mountPath = "/secrets";
                            readOnly = true;
                          }
                        ];
                      }
                    ];
                    volumes = [
                      {
                        name = "config";
                        configMap.name = "seerr-bootstrap";
                      }
                      {
                        name = "secrets";
                        projected = {
                          defaultMode = 288;
                          sources = [
                            {
                              secret = {
                                name = "media-arr-api-keys";
                                items = [
                                  {
                                    key = "seerr";
                                    path = "api-key";
                                  }
                                  {
                                    key = "sonarr";
                                    path = "sonarr";
                                  }
                                  {
                                    key = "radarr";
                                    path = "radarr";
                                  }
                                ];
                              };
                            }
                            # jellarr's Admin (kubernetes/services/media/jellyfin.nix), for
                            # the first setup only.
                            {
                              secret = {
                                name = "jellyfin-secrets";
                                items = [
                                  {
                                    key = "admin-password";
                                    path = "admin-password";
                                  }
                                ];
                              };
                            }
                          ];
                        };
                      }
                    ];
                  };
                };
              };
            };

            secrets.seerr-oidc-client-secret = {
              type = "Opaque";
              stringData.client-secret = config.age.secrets.seerr-oidc-client-secret.sopsRef;
            };
          };
        };
      };
  };
}
