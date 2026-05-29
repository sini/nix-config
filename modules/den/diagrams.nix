# Fleet and per-host diagrams — generates TOPOLOGY.md with mermaid
# visualizations and per-host view files under diagrams/.
#
# Uses den's capture layer + den-diagram rendering library.
{
  den,
  lib,
  inputs,
  ...
}:
let
  diagram = inputs.den-diagram.lib;
  allHosts = lib.concatMap builtins.attrValues (builtins.attrValues (den.hosts or { }));

  stripFrontmatter =
    source:
    let
      lines = lib.splitString "\n" source;
      body = builtins.filter (l: !(lib.hasPrefix "%%{init:" l)) lines;
    in
    lib.concatStringsSep "\n" body;
in
{
  flake-file.inputs.den-diagram = {
    url = "github:denful/den-diagram";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  perSystem =
    { pkgs, ... }:
    let
      fleetCapture = den.lib.capture.captureFleet { };

      # Patched mermaid-cli: swap bundled mermaid for 11.14.0
      mermaidCliPatched = pkgs.mermaid-cli.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          mermaid_dir="$out/lib/node_modules/@mermaid-js/mermaid-cli/node_modules/mermaid"
          if [ ! -d "$mermaid_dir" ]; then
            echo "mermaidCliPatched: expected $mermaid_dir to exist." >&2
            exit 1
          fi
          rm -rf "$mermaid_dir"
          mkdir -p "$mermaid_dir"
          ${pkgs.gnutar}/bin/tar -xzf ${
            pkgs.fetchurl {
              url = "https://registry.npmjs.org/mermaid/-/mermaid-11.14.0.tgz";
              hash = "sha256-Y7oGZJ4X4Q/uAuVMfC7az+JQtLvds8JJfwDToypC5cc=";
            }
          } -C "$mermaid_dir" --strip-components=1
        '';
      });

      theme = diagram.themeFromBase16 {
        inherit pkgs;
        scheme = "catppuccin-mocha";
      };

      rc = diagram.renderContext {
        inherit pkgs theme;
        mermaidCli = mermaidCliPatched;
        mermaidConfig = {
          layout = "elk";
          elk = {
            mergeEdges = true;
            nodePlacementStrategy = "BRANDES_KOEPF";
          };
          flowchart.wrappingWidth = 600;
        };
      };

      inherit (diagram.export)
        entityEntries
        mkGallery
        mkWriteScript
        entriesToPackages
        ;

      graphClasses = entity: lib.unique (lib.concatMap (n: n.classes or [ ]) entity.nodes);

      # --- Scope projection ---

      hostGraphs = lib.listToAttrs (
        map (host: {
          inherit (host) name;
          value = diagram.projectScope {
            inherit fleetCapture;
            kind = "host";
            inherit (host) name;
          };
        }) allHosts
      );

      # --- Per-host entries ---

      hostViewDefs = classes: rc.views.host ++ rc.views.classViews classes;

      hostEntries = lib.concatMap (
        host:
        let
          entity = hostGraphs.${host.name};
        in
        entityEntries { inherit pkgs rc; } {
          inherit entity;
          inherit (host) name;
          dir = "hosts/${host.name}";
          viewDefs = hostViewDefs (graphClasses entity);
        }
      ) allHosts;

      # --- Per-host summaries ---

      hostSummaryDrvs = lib.listToAttrs (
        map (
          host:
          let
            entity = hostGraphs.${host.name};
            text = diagram.text.hostSummary {
              graph = entity;
              inherit fleetCapture;
            };
          in
          {
            name = "${host.name}-summary";
            value = pkgs.writeText "${host.name}-summary.md" text;
          }
        ) allHosts
      );

      hostSummaryEntries = map (host: {
        inherit (host) name;
        view = "summary";
        dir = "hosts/${host.name}";
        ext = "md";
        tool = null;
        drv = hostSummaryDrvs."${host.name}-summary";
      }) allHosts;

      # --- Per-user entries ---
      # Discover users from fleet capture scope data (not host.users)

      userViewDefs = classes: rc.views.user ++ rc.views.classViews classes;

      allUsers =
        let
          inherit (fleetCapture) scopeEntityKind scopeParent;
          allScopeIds = builtins.attrNames scopeParent;
          userScopes = builtins.filter (s: (scopeEntityKind.${s} or null) == "user") allScopeIds;
          extractName =
            kind: scopeId:
            let
              parts = lib.splitString "," scopeId;
              matching = builtins.filter (p: lib.hasPrefix "${kind}=" p) parts;
            in
            if matching == [ ] then null else lib.removePrefix "${kind}=" (builtins.head matching);
        in
        lib.concatMap (
          s:
          let
            userName = extractName "user" s;
            hostName = extractName "host" s;
          in
          lib.optional (userName != null && hostName != null) {
            inherit userName hostName;
            name = "${hostName}-${userName}";
          }
        ) userScopes;

      userEntries = lib.concatMap (
        u:
        let
          entity = diagram.projectScope {
            inherit fleetCapture;
            kind = "user";
            name = u.userName;
          };
        in
        entityEntries { inherit pkgs rc; } {
          inherit entity;
          name = u.userName;
          dir = "hosts/${u.hostName}/users/${u.userName}";
          viewDefs = userViewDefs (graphClasses entity);
        }
      ) allUsers;

      # --- TOPOLOGY.md sections (inline mermaid for GitHub rendering) ---

      mkInlineSection =
        title: renderFn:
        let
          source = stripFrontmatter (renderFn fleetCapture);
        in
        ''
          ## ${title}

          ```mermaid
          ${source}
          ```
        '';

      fleetSummaryText = diagram.text.fleetSummary fleetCapture;

      # --- Fleet view entries (md + svg pairs) ---

      mkFleetView =
        name: title: renderFn:
        let
          source = renderFn fleetCapture;
          md = pkgs.writeText "${name}.md" "# ${title}\n\n![${title}](./${name}.mmd.svg)\n\n```mermaid\n${source}\n```\n";
          svg = rc.mmdSourceToSvg name source;
        in
        {
          inherit md svg;
        };

      mkFleetEntries = viewName: view: [
        {
          name = "fleet";
          view = viewName;
          dir = "fleet";
          ext = "md";
          tool = null;
          drv = view.md;
        }
        {
          name = "fleet";
          view = viewName;
          dir = "fleet";
          ext = "svg";
          tool = "mmd";
          drv = view.svg;
        }
      ];

      pipeFlowView = mkFleetView "pipe-flow" "Pipe Flow" rc.render.toPipeFlowMermaid;
      scopeTopoView = mkFleetView "scope-topology" "Scope Topology" rc.render.toScopeTopologyMermaid;
      policyMapView =
        mkFleetView "policy-resolution" "Policy Resolution Map"
          rc.render.toPolicyResolutionMapMermaid;
      pipeSeqView = mkFleetView "pipe-sequence" "Pipe Sequence" rc.render.toPipeSequenceMermaid;

      fleetDagSource = rc.render.toFleetDagMermaid { inherit fleetCapture hostGraphs; };
      fleetDagView = {
        md = pkgs.writeText "fleet-dag.md" "# Fleet DAG\n\n![Fleet DAG](./fleet-dag.mmd.svg)\n\n```mermaid\n${fleetDagSource}\n```\n";
        svg = rc.mmdSourceToSvg "fleet-dag" fleetDagSource;
      };

      namespaceGraph = diagram.graph.ofNamespace {
        inherit (den) aspects;
        filter = v: v.name != "wsl-host-aspect";
      };
      namespaceSource = rc.renderDense.toMermaid namespaceGraph;
      namespaceView = {
        md = pkgs.writeText "namespace.md" "# Namespace\n\n![Namespace](./namespace.mmd.svg)\n\n```mermaid\n${namespaceSource}\n```\n";
        svg = rc.mmdSourceToSvg "namespace" namespaceSource;
      };

      fleetIrDrv = pkgs.runCommand "fleet-ir.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
        echo ${
          lib.escapeShellArg (diagram.fleetGraph.toJSON { inherit fleetCapture hostGraphs; })
        } | jq . > $out
      '';

      fleetSummaryDrv = pkgs.writeText "fleet-summary.md" (diagram.text.fleetSummary fleetCapture);

      fleetViewEntries =
        mkFleetEntries "pipe-flow" pipeFlowView
        ++ mkFleetEntries "scope-topology" scopeTopoView
        ++ mkFleetEntries "policy-resolution" policyMapView
        ++ mkFleetEntries "pipe-sequence" pipeSeqView
        ++ mkFleetEntries "fleet-dag" fleetDagView
        ++ mkFleetEntries "namespace" namespaceView
        ++ [
          {
            name = "fleet";
            view = "summary";
            dir = "fleet";
            ext = "md";
            tool = null;
            drv = fleetSummaryDrv;
          }
          {
            name = "fleet";
            view = "fleet-ir";
            dir = "fleet";
            ext = "json";
            tool = null;
            drv = fleetIrDrv;
          }
        ];

      # --- Assembly ---

      everyEntry = hostEntries ++ hostSummaryEntries ++ userEntries ++ fleetViewEntries;

      # --- Galleries ---

      hostGalleries = map (host: {
        path = "diagrams/hosts/${host.name}.md";
        drv = mkGallery pkgs {
          inherit (host) name;
          dir = "hosts/${host.name}";
          title = "Gallery: ${host.name}";
          entries = everyEntry;
        };
      }) allHosts;

      fleetGallery = {
        path = "diagrams/fleet.md";
        drv = mkGallery pkgs {
          name = "fleet";
          dir = "fleet";
          title = "Fleet Gallery";
          entries = everyEntry;
        };
      };

      userGalleries = map (u: {
        path = "diagrams/hosts/${u.hostName}/users/${u.userName}.md";
        drv = mkGallery pkgs {
          name = u.userName;
          dir = "hosts/${u.hostName}/users/${u.userName}";
          title = "Gallery: ${u.userName} @ ${u.hostName}";
          entries = everyEntry;
        };
      }) allUsers;

      galleries = hostGalleries ++ userGalleries ++ [ fleetGallery ];

      # --- TOPOLOGY.md ---

      topologyDrv = pkgs.writeText "TOPOLOGY.md" (
        lib.concatStringsSep "\n" [
          "# Fleet Topology"
          ""
          "Auto-generated visualizations of the nix-config fleet's"
          "aspect-resolution pipeline, scope tree, and data flow."
          ""
          (mkInlineSection "Scope Topology" rc.render.toScopeTopologyMermaid)
          (mkInlineSection "Policy Resolution" rc.render.toPolicyResolutionMapMermaid)
          (mkInlineSection "Pipe Flow" rc.render.toPipeFlowMermaid)
          (mkInlineSection "Pipe Sequence" rc.render.toPipeSequenceMermaid)
          ''
            ## Fleet Summary

            ${fleetSummaryText}
          ''
        ]
      );
    in
    {
      # Diagram packages live in legacyPackages to avoid forcing the expensive
      # fleet capture + graph rendering when the eval cache walks packages.*.
      legacyPackages.diagrams =
        entriesToPackages everyEntry
        // hostSummaryDrvs
        // {
          fleet-summary = fleetSummaryDrv;

          write-topology = pkgs.writeShellScriptBin "write-topology" ''
            dest="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
            cp ${topologyDrv} "$dest/TOPOLOGY.md"
            chmod 644 "$dest/TOPOLOGY.md"
            echo "Wrote $dest/TOPOLOGY.md"
          '';

          write-diagrams = mkWriteScript pkgs {
            entries = everyEntry;
            inherit galleries;
            readmeDrv = topologyDrv;
            destExpr = ''"$(${pkgs.git}/bin/git rev-parse --show-toplevel)"'';
          };
        };
    };
}
