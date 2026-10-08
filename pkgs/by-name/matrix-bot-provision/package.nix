{
  writeShellApplication,
  age,
  age-plugin-yubikey,
  curl,
  git,
  jq,
  kubectl,
}:
writeShellApplication {
  name = "matrix-bot-provision";
  meta.description = "Join @genie to a room with its agenix-generated token and print the rooms setting";
  runtimeInputs = [
    age
    age-plugin-yubikey
    curl
    git
    jq
    kubectl
  ];
  text = builtins.readFile ./matrix-bot-provision.sh;
}
