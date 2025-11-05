{
  flake.features.ceph.nixos = {
    environment.persistence."/persist".directories = [

    ];
  };
}
