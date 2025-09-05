{ rootPath, ... }:
{
  flake.modules.nixos.kanidm = {
    age.secrets.kanidm-admin-password = {
      rekeyFile = rootPath + "/.secrets/services/kanidm-admin-password.age";
    };
  };
}
