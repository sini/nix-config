# Fleet topology diagrams — generates TOPOLOGY.md with mermaid visualizations.
#
# Uses den's capture layer + den-diagram rendering library to produce
# scope topology, policy resolution, pipe flow, and namespace diagrams.
{
  den,
  lib,
  inputs,
  ...
}:
let
  diagram = inputs.den-diagram.lib;

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

      rc = diagram.renderContext { inherit pkgs; };

      scopeTopologySection =
        let
          source = stripFrontmatter (rc.render.toScopeTopologyMermaid fleetCapture);
        in
        ''
          ## Scope Topology

          The scope tree shows how den organizes entities hierarchically.
          Each node is a scope — a context in which aspects and policies are
          evaluated. Child scopes inherit their parent's context bindings.

          ```mermaid
          ${source}
          ```
        '';

      policyResolutionSection =
        let
          source = stripFrontmatter (rc.render.toPolicyResolutionMapMermaid fleetCapture);
        in
        ''
          ## Policy Resolution

          Policies fire at each scope and produce effects: resolving child
          entities, providing configuration, or collecting data.

          ```mermaid
          ${source}
          ```
        '';

      pipeFlowSection =
        let
          source = stripFrontmatter (rc.render.toPipeFlowMermaid fleetCapture);
        in
        ''
          ## Pipe Flow

          Pipes allow hosts to share data. Each host emitting a quirk
          contributes to a collected dataset available to peers.

          ```mermaid
          ${source}
          ```
        '';

      pipeSequenceSection =
        let
          source = stripFrontmatter (rc.render.toPipeSequenceMermaid fleetCapture);
        in
        ''
          ## Pipe Sequence

          Sequence diagram showing emit → collect flow for each pipe.

          ```mermaid
          ${source}
          ```
        '';

      namespaceSection =
        let
          namespaceGraph = diagram.graph.ofNamespace {
            aspects = den.aspects;
            filter = v: v.name != "wsl-host-aspect";
          };
          source = stripFrontmatter (rc.renderDense.toMermaid namespaceGraph);
        in
        ''
          ## Aspect Namespace

          All declared aspects and their include hierarchy.

          ```mermaid
          ${source}
          ```
        '';

      fleetSummarySection =
        let
          summaryText = diagram.text.fleetSummary fleetCapture;
        in
        ''
          ## Fleet Summary

          Tabular overview of resolved topology: environment membership,
          aspect distribution, pipe relationships, and policy execution.

          ${summaryText}
        '';

      legendSection = ''
        ## Legend

        | Concept | Description |
        |---------|-------------|
        | **Scope** | A context where aspects and policies evaluate. Scopes inherit parent bindings. |
        | **Policy** | A function that fires at a scope and produces effects. |
        | **Aspect** | A reusable unit of configuration emitting class modules and quirk data. |
        | **Pipe / Quirk** | A data channel between scopes. One aspect emits, peers collect via `pipe.collect`. |
        | **Entity** | A named scope with identity: fleet, environment, host, user, or cluster. |
      '';

      mkViewFile = name: content: {
        inherit name;
        view = name;
        dir = "fleet";
        ext = "md";
        tool = null;
        drv = pkgs.writeText "${name}.md" content;
      };

      everyEntry = [
        (mkViewFile "scope-topology" scopeTopologySection)
        (mkViewFile "policy-resolution" policyResolutionSection)
        (mkViewFile "pipe-flow" pipeFlowSection)
        (mkViewFile "pipe-sequence" pipeSequenceSection)
        (mkViewFile "namespace" namespaceSection)
        (mkViewFile "summary" fleetSummarySection)
      ];

      topologyDrv = pkgs.writeText "TOPOLOGY.md" (
        lib.concatStringsSep "\n" [
          "# Fleet Topology"
          ""
          "Auto-generated visualizations of the nix-config fleet's"
          "aspect-resolution pipeline, scope tree, and data flow."
          ""
          legendSection
          scopeTopologySection
          policyResolutionSection
          pipeFlowSection
          pipeSequenceSection
          namespaceSection
          fleetSummarySection
        ]
      );
    in
    {
      packages = diagram.export.entriesToPackages everyEntry // {
        write-topology = pkgs.writeShellScriptBin "write-topology" ''
          dest="$(${pkgs.git}/bin/git rev-parse --show-toplevel)"
          cp ${topologyDrv} "$dest/TOPOLOGY.md"
          chmod 644 "$dest/TOPOLOGY.md"
          echo "Wrote $dest/TOPOLOGY.md"
        '';
      };
    };
}
