{
  writeShellApplication,
  age,
  sops,
  git,
}:
writeShellApplication {
  name = "convert-oidc-secrets";
  meta.description = "Convert existing age-encrypted OIDC secrets to SOPS-encrypted YAML format";
  runtimeInputs = [
    age
    sops
    git
  ];
  excludeShellChecks = [ "SC2094" ];
  text = builtins.readFile ./convert-oidc-secrets.sh;
}
