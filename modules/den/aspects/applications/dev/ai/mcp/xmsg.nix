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
# genie-guard (github:sini/genie-agent): on a host that runs the @genie bot, the
# owner's user service registers on this bus as svc:genie-guard and answers guard-in
# requests with a model's verdict; xmsg admits that name only from its own binary.
{ den, lib, ... }:
let
  fedPair = [
    "bitstream"
    "cortex"
  ];
  keyName = "xmsg-sini";
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
    };

    nixos =
      { environment, host, ... }:
      lib.mkIf (fedOf host).enable {
        assertions = [
          {
            assertion = lib.elem host.name fedPair;
            message = "xmsg federation: ${host.name} is not in fedPair (${toString fedPair}).";
          }
        ];

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

        # No firewall rule: the tailnet interface is trusted (core.network.tailscale),
        # so the port is reachable over the tailnet and nowhere else, and the pin
        # admits only the peer.
      };

    # Folded into the MCP registry of every agent aspect that reads agent-extensions
    # (agents/claude.nix, agents/antigravity-cli.nix).
    agent-extensions =
      { lib, pkgs, ... }:
      {
        type = "mcp";
        mcpServers.xmsg = {
          command = lib.getExe pkgs.local.xmsg;
          args = [ "mcp" ];
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
            "${crtOf host}"
            "--fed-key"
            osConfig.age.secrets.${keyName}.path
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
        peersFile =
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
        # $XDG_RUNTIME_DIR/xmsg/http.sock (peer uid checked); --listen adds TCP on
        # loopback, reachable by every local uid. Loopback only; widening --listen
        # exposes every session to anyone who can reach the port.
        # TODO: drop --listen once its two TCP-only consumers speak http.sock:
        #   - matrix-xmsg (@genie bot, bitstream): a DynamicUser HTTP client of
        #     xmsgUrl, with no Unix-socket transport and a foreign uid;
        #   - xmsg-pi's `list` tool (extensions/pi/index.ts), which fetches
        #     $XMSG_URL, default http://127.0.0.1:7787.
        # The genie tier instances (services/ai/genie-xmsg.nix) never take it.
        systemd.user.services.xmsg = {
          Unit.Description = "xmsg: bridge into running agent sessions";
          Service = {
            ExecStart = "${xmsg} serve --listen 127.0.0.1:7787 ${identityArgs}";
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
