{
  inputs,
  system,
  ...
}:
let
  inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
in
fromCRD {
  name = "traefik";
  src = inputs.nixhelm.chartsDerivations.${system}.traefik.traefik;
  crds = [
    "crds/traefik.io_ingressroutes.yaml"
    "crds/traefik.io_ingressroutetcps.yaml"
    "crds/traefik.io_ingressrouteudps.yaml"
    "crds/traefik.io_middlewares.yaml"
    "crds/traefik.io_middlewaretcps.yaml"
    "crds/traefik.io_serverstransports.yaml"
    "crds/traefik.io_serverstransporttcps.yaml"
    "crds/traefik.io_tlsoptions.yaml"
    "crds/traefik.io_tlsstores.yaml"
    "crds/traefik.io_traefikservices.yaml"
  ];
}
