{
  den.aspects.core.security = {
    nixos =
      { pkgs, ... }:
      {
        security.polkit.enable = true;

        security.tpm2 = {
          enable = true;
          abrmd.enable = true;
          pkcs11.enable = true;
          tctiEnvironment.enable = true;
        };

        services.pcscd.enable = true;

        # pcscd ships allow_any=no / allow_inactive=no / allow_active=yes, and
        # "active" means an active local seat. An SSH session never has one, so
        # on a headless host every smartcard client is refused:
        #   winscard_svc.c:357:ContextThread() Rejected unauthorized PC/SC client
        # gpg surfaces that as `selecting card failed: No such device`, which
        # reads like absent hardware rather than a refused authorisation — the
        # YubiKey is enumerated on USB and scdaemon still cannot open it.
        # Granting on group membership rather than session activity is what
        # makes a card usable over SSH; wheel already gates sudo here, so this
        # widens nothing that was not already trusted.
        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if ((action.id == "org.debian.pcsc-lite.access_pcsc" ||
                 action.id == "org.debian.pcsc-lite.access_card") &&
                subject.isInGroup("wheel")) {
              return polkit.Result.YES;
            }
          });
        '';

        environment.systemPackages = [
          pkgs.clevis
          pkgs.jose
        ];
      };

    persist = {
      directories = [
        {
          directory = "/var/lib/swtpm";
          user = "tss";
          group = "tss";
          mode = "0750";
        }
        {
          directory = "/var/lib/swtpm-localca";
          user = "tss";
          group = "tss";
          mode = "0750";
        }
      ];
    };
  };
}
