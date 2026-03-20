{
  environments.dev = {
    access = {
      # system-access grants workstation-access transitively, which includes:
      # wheel, audio, sound, video, networkmanager, input, tty, podman, media, gamemode, render
      sini = [
        "admins"
        "system-access"
        "libvirtd"
        "kvm"
      ];

      # workstation-access grants: wheel, audio, sound, video, networkmanager, input, tty, podman, media, gamemode, render
      shuo = [
        "users"
        "workstation-access"
      ];
      will = [
        "users"
        "workstation-access"
      ];
    };
  };
}
