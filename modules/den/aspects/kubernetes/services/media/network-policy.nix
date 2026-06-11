# Media-namespace Cilium network-policy matrix — the cross-service grant graph.
#
# WHY THIS FILE EXISTS
# --------------------
# Each media app's helper (_media-app.nix) emits only its *baseline* policies:
#   - gateway-ingress  (ingress, routed apps only)  -> engages INGRESS default-deny
#   - dns-egress       (egress, every app)
#   - postgres-egress  (egress, postgres apps)
#   - internet-egress  (egress, flagged apps)
# A few cross-service edges already live with their owning app (single source of
# truth, do NOT re-declare here):
#   - unpackerr -> *arr  egress   (unpackerr.nix:  allow-arr-egress-unpackerr)
#   - recyclarr -> sonarr/radarr   (recyclarr.nix: allow-arr-egress-recyclarr)
#   - *arr+prowlarr+unpackerr -> qbittorrent:8080 ingress (qbittorrent.nix:
#       allow-arr-ingress-qbittorrent — the qbt INGRESS side is complete there)
#   - media-pg -> kube-apiserver  egress (media-pg.nix)
# This aspect closes everything else so EVERY media pod is selected by at least
# one ingress policy AND at least one egress policy.
#
# CILIUM SEMANTICS WE RELY ON (per the docs, verified 2026-06-10)
# --------------------------------------------------------------
# Default-deny is per-endpoint AND per-direction: "If any rule selects an
# Endpoint and the rule has an ingress section, the endpoint goes into
# default-deny mode for ingress. … the same for egress." A policy with only an
# egress section does NOT enable ingress default-deny, and vice-versa.
#
# EGRESS IS ALREADY DEFAULT-DENY CLUSTER-WIDE, BUT OPEN TO IN-CLUSTER PEERS:
# cilium.nix ships a CiliumClusterwideNetworkPolicy `allow-internal-egress` that
# selects every endpoint (endpointSelector = {}) with an egress rule allowing
# egress to all cilium-managed endpoints. So (a) every pod is already egress-
# selected, and (b) in-cluster egress is permitted; only world / special-entity
# egress is denied unless a policy opens it (that's why flaresolverr/sabnzbd get
# internet-egress). We STILL emit the per-source egress edges below — generated
# from the same edge list as the ingress side — so the grant graph is explicit
# and stays correct if `allow-internal-egress` is ever tightened.
#
# INGRESS IS THE REAL WORK: a routed app (sonarr, …) already has gateway-ingress,
# so it is in ingress default-deny and currently rejects in-namespace callers
# (prowlarr/unpackerr/bazarr). The per-target ingress edges below restore those
# flows. Route-less helper pods (flaresolverr, unpackerr, recyclarr) have NO
# ingress policy at all, so they accept all ingress — we add an ingress section
# for each (a real allow for flaresolverr; a default-deny lockdown for the two
# that need no inbound) so every pod is ingress-selected.
#
# unpackerr / recyclarr INGRESS DECISION (see report): neither needs any inbound
# connection (unpackerr polls the *arrs; recyclarr is a CronJob that pushes to
# them). To put them under ingress default-deny WITHOUT inventing a bogus allow,
# we use the unambiguous `enableDefaultDeny.ingress = true` (Cilium ≥1.14): it
# engages ingress default-deny for the selected endpoint with zero allow rules.
# This is the canonical single-direction deny and avoids the `ingress: [{}]`
# foot-gun (an empty rule = allow-all, the opposite of what we want).
#
# DASHBOARDS (Task 10/11: glance, homepage) are PRE-DECLARED as ingress sources
# on the *arr + sabnzbd API ports now, so the dashboard tasks need no edits here.
# Their pods carry app.kubernetes.io/name in {glance, homepage} (app-template
# convention, same as every app here — verified against a rendered Deployment).
# qbittorrent is intentionally NOT in the dashboard set: its ingress is owned by
# qbittorrent.nix and dashboards surface torrents via the *arr download clients.
#
# NFS: scratch/data are kubelet NFS mounts (host netns, outside the pod netns),
# so no pod-level CNP governs them — the absence of NFS issues on the already-
# mounted *arr pods confirms it. No NFS egress policy is needed or emitted.
{ lib, ... }:
let
  ns = "media";

  # Service web/API ports, single source of truth for the edge list.
  ports = {
    prowlarr = 9696;
    sonarr = 8989;
    radarr = 7878;
    lidarr = 8686;
    whisparr = 6969;
    flaresolverr = 8191;
    sabnzbd = 8080;
    qbittorrent = 8080;
  };

  arrs = [
    "sonarr"
    "radarr"
    "lidarr"
    "whisparr"
  ];
  downloaders = [
    "sabnzbd"
    "qbittorrent"
  ];

  # Dashboards (land in Task 10/11) — pre-declared ingress sources on the API
  # ports so their tasks need no edits here.
  dashboards = [
    "glance"
    "homepage"
  ];

  # ---- the edge graph ----------------------------------------------------
  # { from; to; } — every directed in-namespace TCP edge to the target's port.
  # Edges already declared in an owning app file are EXCLUDED here (see header)
  # to keep a single source of truth and avoid duplicate-name resources:
  #   unpackerr->*arr, recyclarr->sonarr/radarr, *->qbittorrent ingress.
  edges =
    # *arr <-> prowlarr (indexer sync, both directions)
    map (a: {
      from = a;
      to = "prowlarr";
    }) arrs
    ++ map (a: {
      from = "prowlarr";
      to = a;
    }) arrs
    # prowlarr -> flaresolverr (cloudflare challenge solving)
    ++ [
      {
        from = "prowlarr";
        to = "flaresolverr";
      }
    ]
    # *arr -> downloaders (download-client registration + queue management)
    ++ lib.concatMap (
      a:
      map (d: {
        from = a;
        to = d;
      }) downloaders
    ) arrs
    # bazarr -> sonarr/radarr (subtitle sync reads series/movie metadata)
    ++ [
      {
        from = "bazarr";
        to = "sonarr";
      }
      {
        from = "bazarr";
        to = "radarr";
      }
    ];

  # The qbittorrent INGRESS side is fully owned by qbittorrent.nix (it aggregates
  # *arr + prowlarr + unpackerr). The *arr -> qbittorrent egress side, however,
  # is ours (it belongs on the *arr pods). So: emit egress for ALL edges, but
  # SKIP generating an ingress policy whose target is qbittorrent.
  ingressTargetExcludes = [ "qbittorrent" ];

  # ---- generators --------------------------------------------------------
  podSel = name: { matchLabels."app.kubernetes.io/name" = name; }; # in-ns app pod
  toPortsTcp = port: [
    {
      ports = [
        {
          port = toString port;
          protocol = "TCP";
        }
      ];
    }
  ];

  uniq = lib.lists.unique;

  sources = uniq (map (e: e.from) edges);
  targets = uniq (map (e: e.to) edges);

  # One egress policy per source: aggregate all its targets (one toEndpoints/
  # toPorts pair per distinct target so ports stay exact).
  egressPolicies = builtins.listToAttrs (
    map (
      src:
      let
        srcEdges = builtins.filter (e: e.from == src) edges;
        targetsOf = uniq (map (e: e.to) srcEdges);
      in
      lib.nameValuePair "allow-media-egress-${src}" {
        spec = {
          description = "Allow ${src} to reach its in-namespace media targets.";
          endpointSelector = podSel src;
          egress = map (t: {
            toEndpoints = [ (podSel t) ];
            toPorts = toPortsTcp ports.${t};
          }) targetsOf;
        };
      }
    ) sources
  );

  # One ingress policy per target: aggregate all its in-namespace sources PLUS
  # the pre-declared dashboard sources (so the dashboard task needs no edits).
  # The qbittorrent target is skipped — qbittorrent.nix owns its ingress.
  ingressTargets = builtins.filter (t: !(builtins.elem t ingressTargetExcludes)) targets;

  # Dashboards consume the *arr + downloader (sab) APIs. flaresolverr has only
  # prowlarr as a caller (internal), no dashboard reads it.
  dashboardConsumes = arrs ++ [ "sabnzbd" ];

  ingressPolicies = builtins.listToAttrs (
    map (
      tgt:
      let
        appSources = uniq (map (e: e.from) (builtins.filter (e: e.to == tgt) edges));
        dashSources = lib.optionals (builtins.elem tgt dashboardConsumes) dashboards;
        allSources = appSources ++ dashSources;
      in
      lib.nameValuePair "allow-media-ingress-${tgt}" {
        spec = {
          description = "Allow in-namespace callers${
            lib.optionalString (dashSources != [ ]) " + dashboards"
          } to reach ${tgt}:${toString ports.${tgt}}.";
          endpointSelector = podSel tgt;
          ingress = [
            {
              fromEndpoints = map podSel allSources;
              toPorts = toPortsTcp ports.${tgt};
            }
          ];
        };
      }
    ) ingressTargets
  );

  # Route-less helper pods that take NO inbound connections: engage ingress
  # default-deny with zero allows via enableDefaultDeny.ingress (the canonical
  # single-direction deny — see header). This makes them ingress-selected so the
  # coverage invariant holds without inventing a bogus allow rule.
  ingressLockdown = builtins.listToAttrs (
    map
      (
        name:
        lib.nameValuePair "deny-media-ingress-${name}" {
          spec = {
            description = "Default-deny all ingress to ${name} (no inbound callers).";
            endpointSelector = podSel name;
            enableDefaultDeny.ingress = true;
          };
        }
      )
      [
        "unpackerr"
        "recyclarr"
      ]
  );

  # media-pg internal mesh: the CNPG instance pods need ingress from
  #   - in-namespace app pods (the postgres-egress'd callers) on 5432
  #   - peer instances (streaming replication) on 5432
  #   - peer instances + the cnpg-system operator on 8000 (instance manager)
  # The instance->apiserver egress is in media-pg.nix; the helper apps' egress
  # to media-pg is the postgres-egress baseline. This closes the media-pg
  # INGRESS side so the cluster pods are ingress-selected and replication +
  # operator reconciliation are explicitly permitted.
  cnpgClusterSel.matchLabels."cnpg.io/cluster" = "media-pg";
  mediaPgInternal = {
    "allow-media-pg-internal".spec = {
      description = "media-pg ingress: app clients (5432), peer replication (5432/8000), CNPG operator status (8000).";
      endpointSelector = cnpgClusterSel;
      ingress = [
        # in-namespace application clients -> postgres 5432
        {
          fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = ns; } ];
          toPorts = toPortsTcp 5432;
        }
        # peer instances -> postgres/replication 5432 and instance-manager 8000
        {
          fromEndpoints = [ cnpgClusterSel ];
          toPorts = [
            {
              ports = [
                {
                  port = "5432";
                  protocol = "TCP";
                }
                {
                  port = "8000";
                  protocol = "TCP";
                }
              ];
            }
          ];
        }
        # CNPG operator (cnpg-system) -> instance-manager status 8000
        {
          fromEndpoints = [ { matchLabels."k8s:io.kubernetes.pod.namespace" = "cnpg-system"; } ];
          toPorts = toPortsTcp 8000;
        }
      ];
    };
  };

  allPolicies = egressPolicies // ingressPolicies // ingressLockdown // mediaPgInternal;
in
{
  den.aspects.kubernetes.services.media.network-policy = {
    k8s-manifests = _: {
      applications.media-network-policy = {
        namespace = ns;
        resources.ciliumNetworkPolicies = allPolicies;
      };
    };
  };
}
