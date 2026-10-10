# xmsg (github:sini/xmsg): lists running agent sessions and delivers messages into
# them. Anonymous callers (scripts, CI, other hosts over ssh) use HTTP on loopback;
# agents use the `xmsg mcp` tools, whose send/reply go over agent.sock and are
# attested by SO_PEERCRED, so an agent can never claim another session's identity.
#
# The input SOURCE builds our own `xmsg` package (pkgs/by-name/xmsg), threaded to
# callPackage as `xmsg-src` by the overlay in pkgs/overlays.nix.
#
# Federation: the system owner's node on each host of `fedPair` federates with the
# other's over pinned mTLS (xmsg-links `sini@bitstream ↔ sini@cortex : send, reply,
# list`, federation plan §6.1). The node key is an `xmsg-identity` agenix secret
# whose public .crt sidecar is committed beside the .age; the peer's pin is computed
# from that .crt at build time.
#
# With federation.ca.enable on both, the pair authenticates by CA instead (xmsg X16,
# federation plan §6.7): each node presents a leaf signed by the host intermediate,
# whose URI SAN is its spiffe://json64.dev/host/<host>/user/<user> identity, and
# each peer entry trusts the root .crt with that one identity. The root and both
# intermediates are fleet-wide `intermediary` secrets under .secrets/xmsg-ca: only
# `agenix generate` decrypts them, never a host. The cluster intermediate is
# cert-manager's issuer (not wired here).
#
# genie-guard (github:sini/genie-agent): on a host that runs the @genie bot, the
# owner's user service registers on this bus as svc:genie-guard and answers guard-in
# requests with a model's verdict; xmsg admits that name only from its own binary.
{
  den,
  lib,
  self,
  ...
}:
let
  fedPair = [
    "bitstream"
    "cortex"
  ];
  keyName = "xmsg-sini";
  leafName = "${keyName}-fed-ca";
  caDir = self + "/.secrets/xmsg-ca";
  spiffeOf = host: "spiffe://json64.dev/host/${host.name}/user/${host.system-owner}";
  fedOf = host: host.settings.applications.dev.ai.mcp.xmsg.federation;
  peerOf = host: den.hosts.x86_64-linux.${lib.head (lib.remove host.name fedPair)};
  # The committed public half of a host's node key, refused by name until generated.
  crtOf =
    host:
    let
      crt = host.secretPath + "/${keyName}.crt";
    in
    if builtins.pathExists crt then
      crt
    else
      throw ''
        xmsg federation: ${host.name} has no node certificate ${keyName}.crt in its secretPath.
        Set settings.applications.dev.ai.mcp.xmsg.federation.enable on ${lib.concatStringsSep " and " fedPair}
        (it declares each node key), then run `agenix generate`, `git add` the .age and .crt
        files, and `agenix rekey`.
      '';
  # A committed CA .crt sidecar, refused by name until generated. Copied alone, so a
  # path under `self` does not pull the whole flake source into the store path.
  caCrt =
    crt:
    if builtins.pathExists crt then
      builtins.path {
        path = crt;
        name = baseNameOf crt;
      }
    else
      throw ''
        xmsg federation: ${toString crt} is absent. Set
        settings.applications.dev.ai.mcp.xmsg.federation.ca.enable on ${lib.concatStringsSep " and " fedPair},
        then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.
      '';
in
{
  flake-file.inputs.xmsg = {
    url = "github:sini/xmsg";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  flake-file.inputs.genie-agent = {
    url = "github:sini/genie-agent";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.applications.dev.ai.mcp.xmsg = {
    settings.genieGuard.ninferUrl = lib.mkOption {
      type = lib.types.strMatching "https?://.+";
      default = "http://10.9.2.2:18020/v1";
      description = "OpenAI-compatible endpoint genie-guard asks for its verdicts (hyperqwen on cortex-cuda).";
    };

    settings.federation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Federate the system owner's xmsg with its fedPair peer. agenix-rekey refuses to evaluate a declared key whose .age is absent, and `agenix generate` creates only declared ones, so set this on both hosts, then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.";
      };
      port = lib.mkOption {
        type = lib.types.port;
        default = 7788;
        description = "The owner node's federation listener port (federation plan §6.4).";
      };
      ca.enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Declare the xmsg CA (root, host and cluster intermediates under .secrets/xmsg-ca) and this host's CA-signed leaf, and federate with them instead of the pinned node key. Set it on both fedPair hosts, then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        ...
      }:
      let
        fed = fedOf host;
        ca = name: deps: script: {
          rekeyFile = caDir + "/${name}.age";
          intermediary = true;
          generator = {
            inherit script;
            dependencies = deps;
          };
          settings.cn = "json64.dev xmsg ${name} CA";
        };
        root = config.age.secrets.xmsg-ca-root;
      in
      lib.mkMerge [
        (lib.mkIf fed.enable {
          assertions = [
            {
              assertion = lib.elem host.name fedPair;
              message = "xmsg federation: ${host.name} is not in fedPair (${toString fedPair}).";
            }
            {
              assertion = fed.ca.enable -> (fedOf (peerOf host)).ca.enable;
              message = "xmsg federation: ca.enable is set on ${host.name} but not on its peer; set it on both.";
            }
          ];

          # No firewall rule: the tailnet interface is trusted (core.network.tailscale),
          # so the port is reachable over the tailnet and nowhere else, and the pin
          # or the CA identity admits only the peer.
        })

        (lib.mkIf (fed.enable && !fed.ca.enable) {
          age.secrets.${keyName} = {
            rekeyFile = host.secretPath + "/${keyName}.age";
            generator.script = "xmsg-identity";
            settings = {
              node = "${host.system-owner}@${host.name}";
              san = "${host.name}.ts.${environment.domain}";
            };
            owner = host.system-owner;
            mode = "0400";
          };
        })

        (lib.mkIf fed.ca.enable {
          age.secrets = {
            xmsg-ca-root = ca "root" [ ] "x509-ca-root";
            xmsg-ca-host-intermediate = ca "host-intermediate" [ root ] "x509-ca-intermediate";
            xmsg-ca-cluster-intermediate = ca "cluster-intermediate" [ root ] "x509-ca-intermediate";
            ${leafName} = {
              rekeyFile = host.secretPath + "/${leafName}.age";
              generator = {
                script = "x509-spiffe-leaf";
                dependencies = [
                  config.age.secrets.xmsg-ca-host-intermediate
                  root
                ];
              };
              settings = {
                cn = "${host.system-owner}@${host.name}";
                uri = spiffeOf host;
              };
              owner = host.system-owner;
              mode = "0400";
            };
          };
        })
      ];

    # Folded into the MCP registry and skills of every agent aspect that reads
    # agent-extensions (agents/claude.nix, agents/antigravity-cli.nix,
    # agents/opencode.nix); pi installs the same two skills itself (agents/pi/pi.nix).
    # The matrix skill ships with the bot, so it changes with the bot's protocol.
    agent-extensions =
      {
        inputs',
        lib,
        pkgs,
        ...
      }:
      {
        type = "mcp";
        mcpServers.xmsg = {
          command = lib.getExe pkgs.local.xmsg;
          args = [ "mcp" ];
        };
        skills = {
          xmsg = ./_skills/xmsg;
          matrix = inputs'.matrix-xmsg.packages.matrix-skill;
        };
      };

    homeManager =
      {
        config,
        environment,
        host,
        inputs',
        osConfig,
        pkgs,
        ...
      }:
      let
        xmsg = lib.getExe pkgs.local.xmsg;

        # Identity anchor, pinned to the exact store path of what this home runs:
        # xmsg compares the kernel-reported executable against it, so a profile
        # symlink or another version would fail closed. bin/agy is the real ELF
        # binary (no wrapper). pi is admitted on the peer uid alone (xmsg X11).
        agyExe = "${config.programs.antigravity-cli.package}/bin/agy";
        # The @genie bot registers on this bus as svc:matrix-xmsg (matrix-xmsg M13) on a host
        # that runs it; xmsg admits that name only from the bot's own binary.
        botEnabled = (host.settings.services.matrix-xmsg.rooms or [ ]) != [ ];
        guardEnabled = botEnabled && config.home.username == host.system-owner;
        guardExe = lib.getExe inputs'.genie-agent.packages.genie-guard;
        identityArgs = lib.escapeShellArgs (
          [
            "--agy-exe"
            agyExe
          ]
          ++ lib.optionals botEnabled [
            "--svc-exe"
            "matrix-xmsg=${lib.getExe inputs'.matrix-xmsg.packages.default}"
          ]
          ++ lib.optionals guardEnabled [
            "--svc-exe"
            "genie-guard=${guardExe}"
          ]
          ++ lib.optionals (fed.enable && config.home.username == host.system-owner) [
            "--fed-listen"
            "0.0.0.0:${toString fed.port}"
            "--fed-cert"
            (if fed.ca.enable then "${caCrt (host.secretPath + "/${leafName}.crt")}" else "${crtOf host}")
            "--fed-key"
            osConfig.age.secrets.${if fed.ca.enable then leafName else keyName}.path
            "--peers-file"
            "${peersFile}"
          ]
        );

        fed = fedOf host;
        peer = peerOf host;
        peerNode = "${peer.system-owner}@${peer.name}";
        # The pin is the SHA-256 of the cert's DER SubjectPublicKeyInfo, as xmsg's
        # spki_sha256_from_der computes it (src/fed.rs). No `from`: the host data
        # carries no tailnet address. No `targets`: the peer is the owner's own node.
        # `list` follows the link's spec; xmsg has no federated list route yet.
        # Under ca.enable the entry trusts the root with the peer's one identity.
        peersFile =
          if fed.ca.enable then
            pkgs.writeText "xmsg-peers.json" (
              builtins.toJSON {
                ${peerNode} = {
                  address = "${peer.name}.ts.${environment.domain}:${toString (fedOf peer).port}";
                  ca = "${caCrt (caDir + "/root.crt")}";
                  identities = [ (spiffeOf peer) ];
                  allow = [
                    "send"
                    "reply"
                    "list"
                  ];
                };
              }
            )
          else
            pkgs.runCommand "xmsg-peers.json"
              {
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.openssl
                ];
              }
              ''
                openssl x509 -in ${crtOf peer} -pubkey -noout > pub.pem
                openssl pkey -pubin -in pub.pem -outform DER > spki.der
                pin=$(sha256sum spki.der | cut -d' ' -f1)
                jq -n --arg name ${peerNode} --arg pin "sha256:$pin" \
                  --arg address ${peer.name}.ts.${environment.domain}:${toString (fedOf peer).port} \
                  '{($name): {address: $address, pin: $pin, allow: ["send", "reply", "list"]}}' > $out
              '';
      in
      lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        home.packages = [ pkgs.local.xmsg ];

        # Runs as the sessions' own user: the inbox sockets live in 0700 dirs, and
        # xmsg's own sockets require $XDG_RUNTIME_DIR. Its HTTP API is
        # $XDG_RUNTIME_DIR/xmsg/http.sock (peer uid checked), with no TCP
        # listener: --listen would expose every session to every local uid.
        systemd.user.services.xmsg = {
          Unit.Description = "xmsg: bridge into running agent sessions";
          Service = {
            ExecStart = "${xmsg} serve ${identityArgs}";
            Restart = "on-failure";
          };
          Install.WantedBy = [ "default.target" ];
        };

        # The api-key file is the hyperqwen home-manager secret, decrypted for the owner.
        systemd.user.services.genie-guard = lib.mkIf guardEnabled {
          Unit = {
            Description = "genie-guard: guard-in verdicts for the @genie bot";
            After = [ "xmsg.service" ];
            Wants = [ "xmsg.service" ];
          };
          Service = {
            ExecStart = lib.escapeShellArgs [
              guardExe
              "--ninfer-url"
              host.settings.applications.dev.ai.mcp.xmsg.genieGuard.ninferUrl
              "--api-key-file"
              "%h/.config/hyperqwen/api-key"
            ];
            Restart = "on-failure";
            RestartSec = 10;
          };
          Install.WantedBy = [ "default.target" ];
        };

        # The owner's explicit authorization of the three tools. Allowed calls skip
        # the auto-mode classifier, so the tools must never be requiresUserInteraction.
        programs.claude-code.settings.permissions.allow = [
          "mcp__xmsg__list"
          "mcp__xmsg__send"
          "mcp__xmsg__reply"
        ];

        # agy registers its language-server credentials before every turn. `--hook` reads them
        # from the hook's stdin JSON: agy passes them there, not in the environment, and
        # without the flag the registration fails silently every turn. The hook always
        # prints {"injectSteps":[]} and exits 0, even with the server down.
        home.file.".gemini/config/hooks.json".text = builtins.toJSON {
          xmsg-register.PreInvocation = [
            {
              type = "command";
              command = "${xmsg} register agy --hook";
            }
          ];
        };
      };
  };
}
