{ rootPath, ... }:
{
  flake.user.sini = {
    userConfig =
      { config, ... }:
      {
        age.secrets.user-sini-password = {
          rekeyFile = rootPath + "/.secrets/user-passwords/sini.age";
        };

        users = {
          deterministicIds.sini = {
            uid = 1000;
            gid = 1000;
            subUidRanges = [
              {
                startUid = 100000;
                count = 65536;
              }
            ];
            subGidRanges = [
              {
                startGid = 100000;
                count = 65536;
              }
            ];
          };

          groups.sini.gid = config.users.users.sini.uid;

          users.sini = {
            isNormalUser = true;
            hashedPasswordFile = config.age.secrets.user-sini-password.path;
            home = "/home/sini";
            group = "sini";
            openssh.authorizedKeys.keys = [
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC2KomSUc6hK7QyOCb1AAG00S7ZqVeXqGKvS0po5HishO6YFgr9cPvST6rdxAYreO6b20bLQ8e4Rns3yrGNekWww8Yl32dFdmv0sC1VPZrfJPFKg0qC+imjk3vGDohYII9/3cyDBBb2WuZzupCGSTi+g14AA6/csJXYwN0bQfh/XmLp1OrbrFzmCZEwAWFni95DNMo5WxLeqdUXJxM6is77AzLYbRX7TQqBvdaTyyGjzh6uVi6CkDVJSnhMp3kPRhzqudXyW1RN680U+tgsyDhX+S5AHxgqHZ1OWLkKl+N87ov77rawGXVUEQO1d2ZnOcIwnTQak6rgyiLtPKY81if7mQm53LB0sEsM7Czm9sv1J0RbnR7HwjoygIApDeD29xfTvM4WlYpIn3pk1auS/ZTLQVqg8tx/WhNko5n+DsWCcSIPZ/chu3vs3dvegbYn9QTbEMfHxMp5iLbb3EOmNG08z9M+MQ2gIzbsDPE5KgsEfW84omc9iWy4JvEfvpPyOEKiRf7Ou8bawPDP6tvJv8P7fwEyxfRmhya8hM+ThbUEmPYydwUXJHZ2BkIXk+/1LsTg1lmfADqYb0i2I++1T3C7NbSvYsQ0BobQrIiulkVWzvb/1KuuRcGr4bRxxumJNzmmLWUJLUnWV/ya2h4FAoM/uRPyICGfGeejyycXN1q5mQ== cardno:31_057_490"
              "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDL5nilYJ19sPQPn2Kn07pxuTBmrExbXsmrirLmMWNVh4KLZ2dwl4MFce6/h3b6uY+qijVHNDP5W9BrhMjIK6pbnpPZ4hDNtIoMSkzS1Gjxx5fp6LVoH0Mrf8wZa8JGuZjN088AGFpJ5apBrdw/HpYXwy28m+hwcILsDyF0zEYr7FbcesmenGCHtsSinLp+M9Mfj1bD/w3tFvzsX7FAZGh9ZceVjkgBkodsZAEtFKD2jmRFKviGLSvRrLsO7ZwD9CiZps39KN/jf+3Cxo49wfvISLm4IgqAOld9BCUmn9Jzc9hs56Ry+YKkeR4v3C54sWn77xWZm0zuIwO0cASkzsjTJ1OZ8z3v6g8el2iWqLntbSvtAqZXvnWScArGIuLsTJoGXX2H2j0d99drLX15vtHaIkz89qGgRXZ4rhweDfLv4fiYodMccxC1PgIjpvJURcDa3Ww+3WO0bUbX/JWHH58abmhjBJAlqlzKQBt01JW7soe3t4vDNVNjm7WeZlyVHmWYwBAhBFlTRg4Di0fgAeLt4yhB8mNBiZodlHKclL2u2qU2Ckyb+96nVS2kyxdwI6YaZ8MPgAVb3L+bz9BHHKgE0W/SLU5DejP2Q1EqtrrKy9M8PBHeb5VP1a7y41gdntbkpWmfLaSMzbuqArnVNDhSR0DT35aqOdSeASIAGsWo/Q== sini@ipad"
            ];
            extraGroups = [
              "wheel"
              "audio"
              "sound"
              "video"
              "networkmanager"
              "input"
              "tty"
              "podman"
              "media"
              "gamemode"
              "render"
            ];
            linger = true; # Required for the services start automatically without login
          };
        };
      };
    homeModules = [ ];
  };
}
