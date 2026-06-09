# Nixidy battery: registers the kubernetes classes/quirks, builds per-cluster
# CRDs, and exposes the flake-level nixidy outputs (all-envs package +
# manifest-regen pre-commit hook). The per-cluster nixidy environment itself is
# assembled by the cluster-to-nixidy policy in ../policies/clusters.nix, which
# just collects k8s-manifests modules (including this battery's crds bridge).
{
  config,
  lib,
  inputs,
  withSystem,
  ...
}:
let
  # Forward only the present, non-empty keys of a subset.
  pickNonEmpty =
    keys: attrs:
    lib.filterAttrs (_: v: v != null && v != "" && v != { }) (
      builtins.intersectAttrs (lib.genAttrs keys (_: null)) attrs
    );

  # crds bridge — mirrors agenixClusterAspect. Den collects every cluster
  # aspect's `crds` quirk emission and binds it as the `crds` arg. Those
  # emissions are pkgs-dependent functions, so den's resolveLocalParametric
  # passes them through unresolved (their `pkgs`/`system` args aren't in the
  # pkgs-less walk ctx). The bridge resolves them here — inside mkEnv, where
  # pkgs is a specialArg — and builds each into nixidy *values*: a resource-type
  # module for applicationImports and the raw CRD manifests for the bootstrap
  # app. Building from pkgs (not from mkEnv config) keeps applicationImports out
  # of the module-import fixpoint, so there is no recursion.
  crdsBridge = {
    name = "crds/nixidy";
    k8s-manifests =
      # outer: den args — `crds` (collected quirk specs) and `cluster`
      {
        crds ? [ ],
        cluster,
        ...
      }:
      # inner: nixidy module — pkgs/lib are specialArgs from mkEnv
      { pkgs, lib, ... }:
      let
        system = pkgs.stdenv.hostPlatform.system;
        generators = inputs.nixidy.packages.${system}.generators;
        kubeVersion = "v${cluster.kubeVersion or pkgs.kubernetes.version}";

        buildCrd =
          entry:
          let
            # Most specs are pkgs-deferred functions (passed through raw); resolve
            # with the args den couldn't supply in the pkgs-less walk.
            spec =
              if builtins.isFunction entry then
                entry {
                  inherit
                    pkgs
                    lib
                    inputs
                    system
                    ;
                }
              else
                entry;

            # name becomes the helm release name / app.kubernetes.io/instance
            # label on chart CRDs, so it must be the short, meaningful aspect
            # name. Each crds emission sets it. (A future den-lazy enhancement
            # could thread the aspect's nodeIdentity here and drop the per-spec
            # `name`, but the label is real config worth stating explicitly.)
            name = spec.name;

            # Optional type-generation tuning, forwarded only when the spec sets it.
            typeOpts = pickNonEmpty [ "namePrefix" "attrNameOverrides" "skipCoerceToList" ] spec;
          in
          if spec.chart or null != null || spec.chartAttrs or { } != { } then
            # Chart spec. Both accessors share chartArgs, so the chart is
            # templated once (memoized). Objects deploy every CRD; only the
            # generated types narrow to the spec's `crds` kinds (omitted ⇒ all).
            let
              chartArgs = {
                inherit name kubeVersion;
              }
              // pickNonEmpty [ "chart" "chartAttrs" "values" "extraOpts" ] spec;
            in
            {
              module = generators.fromChartCRDModule (
                chartArgs // lib.optionalAttrs (spec ? crds) { kindFilter = spec.crds; } // typeOpts
              );
              objects = generators.crdObjectsFromChart chartArgs;
            }
          else if spec.src or null != null then
            # Src spec — `crds` is the list of CRD YAML files under `src`.
            {
              module = generators.fromCRDModule (
                {
                  inherit name;
                  inherit (spec) src;
                  crdFiles = spec.crds;
                }
                // typeOpts
              );
              objects = generators.crdObjects {
                inherit (spec) src;
                crdFiles = spec.crds;
              };
            }
          else
            throw "den: a crds emission has neither 'src' nor 'chart'/'chartAttrs' set";

        built = map buildCrd crds;
      in
      {
        nixidy.applicationImports = map (b: b.module) built;
        applications.bootstrap.objects = lib.concatMap (b: b.objects) built;
      };
  };
in
{
  den.classes.k8s-manifests.description = "Kubernetes manifests collected for nixidy";
  den.quirks.crds.description = "CRD specs collected from aspects, built per-cluster into nixidy";

  den.schema.cluster.includes = [ crdsBridge ];

  # nixidy-all-envs: every env's manifests linked together with a manifest.json
  # index. Defined at flake level (not perSystem) because it reads the den
  # pipeline output config.flake.nixidyEnvs, which perSystem cannot reach
  # without a circular dependency.
  flake.packages = lib.genAttrs config.systems (
    system:
    withSystem system (
      { pkgs, ... }:
      let
        envData = lib.mapAttrs (_env: nixidyEnv: {
          inherit (nixidyEnv.config.nixidy.target) repository branch rootPath;
          package = nixidyEnv.environmentPackage;
        }) (config.flake.nixidyEnvs.${system} or { });
      in
      {
        nixidy-all-envs = pkgs.runCommand "nixidy-all-envs" { } ''
          mkdir -p $out
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (env: data: "ln -s ${data.package} $out/${env}") envData
          )}
          cat > $out/manifest.json <<'MANIFEST'
          ${builtins.toJSON (
            lib.mapAttrs (_env: data: {
              inherit (data) repository branch rootPath;
              packagePath = "${data.package}";
            }) envData
          )}
          MANIFEST
        '';
      }
    )
  );

  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # nixidy-sync: run every env's activationPackage. Each activate script
      # writes its rendered manifests to a repo-relative `dest` (e.g.
      # ./generated/manifests/prod-axon), so we cd to the git root first. The
      # activate entrypoint is `<activationPackage>/activate` (not under bin/);
      # it bakes its own target and references rsync by store path, so the only
      # runtime input we need is git. `--skip-secrets` / `-s` sets
      # NIXIDY_SKIP_RENDER=1, preserving the existing encrypted target files
      # instead of re-rendering (no vals/sops/yubikey required).
      #
      # nixidyEnvs is read from the *flake-level* config (inputs.self), not the
      # perSystem config: the cluster-to-nixidy policy builds each env with an
      # overlay that exposes `local = config.packages`, so reading the
      # perSystem config.flake here would risk the package set referencing
      # itself through that overlay.
      packages.nixidy-sync = pkgs.writeShellApplication {
        name = "nixidy-sync";
        runtimeInputs = [ pkgs.git ];
        text = ''
          if [ "''${1:-}" = "--skip-secrets" ] || [ "''${1:-}" = "-s" ]; then
            export NIXIDY_SKIP_RENDER=1
          fi
          cd "$(git rev-parse --show-toplevel)"
          ${lib.concatStringsSep "\n" (
            lib.mapAttrsToList (env: nixidyEnv: ''
              echo "==> Syncing nixidy env: ${env}"
              ${nixidyEnv.activationPackage}/activate
            '') (inputs.self.nixidyEnvs.${system} or { })
          )}
        '';
      };

      pre-commit.settings.hooks.nixidy-sync = {
        enable = true;
        name = "nixidy-sync";
        description = "Run nixidy-sync to re-generate argocd manifests";
        entry = "${config.packages.nixidy-sync}/bin/nixidy-sync --skip-secrets";
        files = "^(flake\\.lock|modules/(den/clusters|den/aspects/kubernetes|den/kubernetes)/.*\\.nix)$";
        pass_filenames = false;
      };
    };
}
