# Mastercard/restapi for OpenTofu (infra/unifi): the gateway's custom NAT rules,
# which the unifi provider has no resource for. Not in nixpkgs, so it lives here,
# where update-pkgs (nix-update) bumps it like any other package.
#
# The shape of nixpkgs' terraform-providers.mkProvider, written out: a call to
# mkProvider puts the version's source position inside nixpkgs, where nix-update
# cannot edit it. The registry.terraform.io address is the one opentofu's
# withPlugins rewrites to registry.opentofu.org.
{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
let
  provider-source-address = "registry.terraform.io/mastercard/restapi";
in
buildGoModule (finalAttrs: {
  pname = "terraform-provider-restapi";
  version = "3.0.0";

  src = fetchFromGitHub {
    owner = "Mastercard";
    repo = "terraform-provider-restapi";
    tag = "v${finalAttrs.version}";
    hash = "sha256-XdOyOIrE090+QzeGQg7sn5GdaH9Jv47HdcuIH1/kDVM=";
  };

  vendorHash = "sha256-O9j62HQEw1d+OEK/9sJpC6FPsVu8cDD0vxwVpvHHCvk=";

  subPackages = [ "." ];
  doCheck = false;
  env.CGO_ENABLED = 0;
  ldflags = [
    "-s"
    "-w"
    "-X main.version=${finalAttrs.version}"
  ];

  postInstall = ''
    dir=$out/libexec/terraform-providers/${provider-source-address}/${finalAttrs.version}/''${GOOS}_''${GOARCH}
    mkdir -p "$dir"
    mv $out/bin/* "$dir/terraform-provider-restapi_${finalAttrs.version}"
    rmdir $out/bin
  '';

  passthru = { inherit provider-source-address; };

  meta = {
    description = "Terraform provider for generic REST APIs";
    homepage = "https://registry.terraform.io/providers/Mastercard/restapi";
    license = lib.licenses.asl20;
  };
})
