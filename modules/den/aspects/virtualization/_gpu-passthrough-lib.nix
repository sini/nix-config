{ lib }:
let
  # Map of passthrough tag → matching criteria against facter hardware reports.
  tagSpec = {
    nvidia.vendorName = "nVidia Corporation";
  };

  # Resolve one passthrough tag to the PCI device records (GPU + its audio
  # function) found in the host facter report.
  matchDevices =
    tag: facter:
    let
      spec = tagSpec.${tag} or (throw "gpu-passthrough: unknown passthrough tag '${tag}'");
      gpu = lib.lists.findFirst (c: c.vendor.name == spec.vendorName) null facter.hardware.graphics_card;
      audio = lib.lists.findFirst (c: c.vendor.name == spec.vendorName) null facter.hardware.sound;
    in
    lib.optional (gpu != null) { busId = gpu.sysfs_bus_id; }
    ++ lib.optional (audio != null) { busId = audio.sysfs_bus_id; };
in
{
  # intents : list of passthrough tags → list of { busId; } records.
  resolvePassthrough = intents: facter: lib.concatMap (tag: matchDevices tag facter) intents;

  # records → microvm.devices entries (PCI bus passthrough).
  toMicrovmDevices = recs: map (d: {
    bus = "pci";
    path = d.busId;
  }) recs;

  # Host-side ExecCondition gate: only start the VM once the GPU's primary PCI
  # function has been unbound from the host (vfio-pci `enable` == "0").
  mkVfioGate =
    pkgs: recs:
    let
      busId = (lib.head recs).busId;
    in
    pkgs.writeScript "check-vfio-${builtins.replaceStrings [ ":" ] [ "-" ] busId}.sh" ''
      #! ${pkgs.runtimeShell} -e
      content=$(< /sys/bus/pci/drivers/vfio-pci/${busId}/enable)
      echo "VFIO enable check: device ${busId} enable=$content" | ${pkgs.systemd}/bin/systemd-cat -t vfio-check -p info
      [ "$content" == "0" ]
    '';
}
