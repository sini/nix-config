# { inputs, ... }:
# {
#   imports = [
#     inputs.sops-nix.nixosModules.sops
#   ];

#   sops = {
#     defaultSopsFile = "${inputs.self}/secrets/global/secrets.yaml";
#     age = {
#       sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];
#       keyFile = "/var/lib/sops-nix/key.txt";
#       generateKey = true;
#     };
#     validateSopsFiles = true;
#   };
# }
_: { }
