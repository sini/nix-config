# Generate an RFC3986 URL-safe secret.
{
  flake.features.agenix-generators.system = _: {
    age.generators.rfc3986-secret =
      { pkgs, ... }:
      ''
        # Generate an rfc3986 secret (URL-safe base64)
        secret=$(${pkgs.openssl}/bin/openssl rand -base64 54 | tr -d '\n' | tr '+/' '-_' | tr -d '=' | cut -c1-72)
        echo "$secret"
      '';
  };
}
