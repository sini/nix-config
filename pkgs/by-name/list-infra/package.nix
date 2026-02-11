{
  writeShellApplication,
  nix,
  jq,
  coreutils,
}:
writeShellApplication {
  name = "list-infra";
  meta.description = "List all flake environments and hosts with details";
  runtimeInputs = [
    nix
    jq
    coreutils
  ];
  text = ''
    echo "=== Flake Environments ==="
    nix eval --json .#environments --apply 'envs: builtins.mapAttrs (name: env: { inherit (env) domain name; }) envs' | \
      jq -r 'to_entries[] | "\(.key) - domain:\(.value.domain)"' | sort

    echo ""
    echo "=== Flake Hosts ==="
    nix eval --json .#hosts --apply 'hosts: builtins.mapAttrs (name: host: { inherit (host) system roles environment ipv4; }) hosts' | \
      jq -r 'to_entries[] | "\(.key) (\(.value.system)) - env:\(.value.environment) roles:\(.value.roles | join(",")) ip:\(.value.ipv4 | join(","))"' | \
      sort
  '';
}
