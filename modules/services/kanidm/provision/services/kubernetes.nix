{
  flake.features.kanidm.nixos = {
    services.kanidm.provision.systems.oauth2.kubernetes = {
      displayName = "kubernetes";
      originUrl = "http://localhost:8000";
      originLanding = "http://localhost:8000";
      # basicSecretFile = config.age.secrets.kubernetes-oidc-client-secret.path;
      public = true;
      enableLocalhostRedirects = true;
      scopeMaps."admins" = [
        "openid"
        "email"
        "profile"
        "groups"
      ];
      preferShortUsername = true;
    };
  };
}
