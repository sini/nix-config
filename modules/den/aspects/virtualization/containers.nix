{
  den,
  lib,
  rootPath,
  ...
}:
{
  # Engine-agnostic containers/image configuration surface: the files under
  # ~/.config/containers/ that podman, buildah and skopeo all read. Included by
  # the podman aspect; rendered into the user (rootless) scope by the
  # homeManager half. System-level container/storage config is owned separately
  # by den.aspects.virtualization.podman.
  den.aspects.virtualization.containers = {
    # (1) DECLARE — one typed knob per containers/image config file. Only
    # `registries` ships a non-empty default (the rest are opt-in so we never
    # inject stale CNI/storage/policy config into rootless scope).
    settings = {
      registries = lib.mkOption {
        type = with lib.types; attrsOf (listOf str);
        default = {
          search = [
            "docker.io"
            "quay.io"
          ];
        };
        description = ''
          Registry resolution policy keyed by class (`search`, `insecure`,
          `block`), rendered to registries.conf in **v2** format: `search`
          populates `unqualified-search-registries`; `insecure`/`block` become
          per-registry `[[registry]]` entries. (NixOS's
          virtualisation.containers module emits the legacy v1 layout, which
          current skopeo rejects with "registries.conf must be in v2 format but
          is in v1" — hence the dedicated renderer.)
        '';
      };

      containersConf = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
        description = ''
          containers.conf settings. Rendered only when non-empty. Defaults to
          empty because podman 5.x here uses netavark, not the CNI defaults the
          upstream module ships.
        '';
      };

      storage = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
        description = ''
          storage.conf settings for the rootless store. Rendered only when
          non-empty: the system graphroot (zfs/overlay/impermanence) is owned by
          the podman aspect and uses a different root than rootless, so it must
          not be mirrored here.
        '';
      };

      policy = lib.mkOption {
        type = with lib.types; attrsOf anything;
        default = { };
        description = ''
          Signature verification policy.json. Rendered only when non-empty;
          otherwise rootless tools fall back to the system policy.
        '';
      };
    };

    # (3) SECRETS — push credentials for the private registry, declared via the
    # age-secrets quirk (collected into HOST agenix by core.secrets.collector,
    # never home-manager agenix). The cleartext password is decrypted from the
    # same prod-env rekeyFile the registry host and k3s nodes share; the
    # auth.json is generated from it via the container-auth generator.
    age-secrets =
      {
        environment,
        config,
        host,
        ...
      }:
      {
        age.secrets = {
          # Recipient of the shared registry password — identical rekeyFile +
          # generator to the registry host's `registry-password`, so agenix-rekey
          # yields the same cleartext here. Pinned to the prod env path (where
          # the registry lives) rather than this host's dev env secretPath.
          registry-password = {
            rekeyFile = rootPath + "/.secrets/env/prod/registry/registry-password.age";
            generator.script = "rfc3986-secret";
          };

          # Generated ~/.config/containers/auth.json content, derived from the
          # password above. Owned by the system user so rootless podman/skopeo/
          # buildah can read the decrypted file through the home symlink.
          registry-auth = {
            rekeyFile = host.secretPath + "/registry-auth.age";
            generator.dependencies = [ config.age.secrets.registry-password ];
            generator.script = "container-auth";
            settings = {
              username = "builder";
              registry = environment.getDomainFor "registry";
            };
            owner = host.system-owner;
          };
        };
      };

    # (4) CONSUME — render each configured file into the user scope. Rootless
    # podman/buildah/skopeo read ~/.config/containers/* in preference to /etc,
    # so this is sufficient to fix rootless tooling without touching /etc.
    homeManager =
      {
        host,
        pkgs,
        config,
        osConfig,
        ...
      }:
      let
        cfg = host.settings.virtualization.containers;
        toml = (pkgs.formats.toml { }).generate;

        registriesV2 = toml "registries.conf" (
          {
            unqualified-search-registries = cfg.registries.search or [ ];
          }
          //
            lib.optionalAttrs ((cfg.registries.insecure or [ ]) != [ ] || (cfg.registries.block or [ ]) != [ ])
              {
                registry =
                  map (location: {
                    inherit location;
                    insecure = true;
                  }) (cfg.registries.insecure or [ ])
                  ++ map (location: {
                    inherit location;
                    blocked = true;
                  }) (cfg.registries.block or [ ]);
              }
        );
      in
      {
        home.packages = with pkgs; [
          skopeo
          buildah
        ];

        xdg.configFile = lib.mkMerge [
          { "containers/registries.conf".source = registriesV2; }
          # Generated push credentials: an out-of-store symlink to the HOST
          # agenix secret's decrypted runtime path (the auth.json IS the secret;
          # no activation script writes it).
          {
            "containers/auth.json".source =
              config.lib.file.mkOutOfStoreSymlink osConfig.age.secrets.registry-auth.path;
          }
          (lib.mkIf (cfg.containersConf != { }) {
            "containers/containers.conf".source = toml "containers.conf" cfg.containersConf;
          })
          (lib.mkIf (cfg.storage != { }) {
            "containers/storage.conf".source = toml "storage.conf" cfg.storage;
          })
          (lib.mkIf (cfg.policy != { }) {
            "containers/policy.json".source = pkgs.writeText "policy.json" (builtins.toJSON cfg.policy);
          })
        ];
      };
  };
}
