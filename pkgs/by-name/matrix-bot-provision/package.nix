{
  writeShellApplication,
  runCommand,
  age,
  age-plugin-yubikey,
  curl,
  git,
  jq,
  kubectl,
  openssl,
  python3,
}:
let
  pkg = writeShellApplication {
    name = "matrix-bot-provision";
    meta.description = "Register @genie on Synapse, save its token as bitstream's agenix secret, join the support room";
    runtimeInputs = [
      age
      age-plugin-yubikey
      curl
      git
      jq
      kubectl
      openssl
      python3
    ];
    text = builtins.readFile ./matrix-bot-provision.sh;
    # Synapse's register MAC on a fixed vector: the script checks python against
    # openssl, and this pins both to a digest computed outside the script.
    passthru.tests.register-mac = runCommand "matrix-bot-provision-register-mac" { } ''
      got=$(${pkg}/bin/matrix-bot-provision --self-test)
      [ "$got" = 18e7152ab3f727d2539fb6ded5d4449eab3443a4 ] || { echo "got $got" >&2; exit 1; }
      echo "$got" > $out
    '';
  };
in
pkg
