# Fleet and per-host diagrams — generates TOPOLOGY.md with mermaid
# visualizations and per-host view files under diagrams/.
#
# Uses den's capture layer + den-diagram rendering library.
{
  den,
  lib,
  inputs,
  self,
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

      # --- Capture helpers ---

      mkHostEntity =
        host:
        let
          captured = den.lib.capture.captureWithPathsWith {
            classes = lib.unique (
              [ "nixos" "homeManager" "user" ]
              ++ lib.concatMap (u: u.classes or [ ]) (lib.attrValues (host.users or { }))
            );
            root = den.lib.resolveEntity "host" { inherit host; };
            ctx = { inherit host; };
          };
        in
        diagram.context {
          inherit (captured) entries ctxTrace pathsByClass;
          name = host.name;
        };

      hostGraphs = lib.listToAttrs (
        map (host: {
          name = host.name;
          value = mkHostEntity host;
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
          name = host.name;
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

      hostSummaryEntries = map (
        host: {
          name = host.name;
          view = "summary";
          dir = "hosts/${host.name}";
          ext = "md";
          tool = null;
          drv = hostSummaryDrvs."${host.name}-summary";
        }
      ) allHosts;

      # --- TOPOLOGY.md sections (inline mermaid for GitHub rendering) ---

      mkInlineSection = title: renderFn: let source = stripFrontmatter (renderFn fleetCapture); in ''
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
        { inherit md svg; };

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
      policyMapView = mkFleetView "policy-resolution" "Policy Resolution Map" rc.render.toPolicyResolutionMapMermaid;
      pipeSeqView = mkFleetView "pipe-sequence" "Pipe Sequence" rc.render.toPipeSequenceMermaid;

      fleetDagSource = rc.render.toFleetDagMermaid { inherit fleetCapture hostGraphs; };
      fleetDagView = {
        md = pkgs.writeText "fleet-dag.md" "# Fleet DAG\n\n![Fleet DAG](./fleet-dag.mmd.svg)\n\n```mermaid\n${fleetDagSource}\n```\n";
        svg = rc.mmdSourceToSvg "fleet-dag" fleetDagSource;
      };

      namespaceGraph = diagram.graph.ofNamespace {
        aspects = den.aspects;
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

      everyEntry = hostEntries ++ hostSummaryEntries ++ fleetViewEntries;

      # --- Galleries ---

      hostGalleries = map (
        host: {
          path = "diagrams/hosts/${host.name}.md";
          drv = mkGallery pkgs {
            name = host.name;
            dir = "hosts/${host.name}";
            title = "Gallery: ${host.name}";
            entries = everyEntry;
          };
        }
      ) allHosts;

      fleetGallery = {
        path = "diagrams/fleet.md";
        drv = mkGallery pkgs {
          name = "fleet";
          dir = "fleet";
          title = "Fleet Gallery";
          entries = everyEntry;
        };
      };

      galleries = hostGalleries ++ [ fleetGallery ];

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
      packages = entriesToPackages everyEntry // hostSummaryDrvs // {
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
