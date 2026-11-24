# Identity-only users (Kanidm/SSO — no Unix accounts, no system-access groups).
# `hosts = [ ]` marks each hostless on purpose (den's hostless-users report).
{
  den.users = {
    json = {
      facts.groups = [ "admins" ];
      classes = [ ];
      hosts = [ ];
    };

    json_user = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Jason-user";
        email = "jason_user@json64.dev";
      };
    };

    greco = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Jason Greco";
        email = "jasonagreco@gmail.com";
      };
    };

    taiche = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Chris Tai";
        email = "christai@gmail.com";
      };
    };

    jennism = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Jennifer Ng";
        email = "jenn.ng@gmail.comm";
      };
    };

    hugs = {
      facts.groups = [
        "users"
        "grafana.server-admins"
      ];
      classes = [ ];
      hosts = [ ];
      identity.displayName = "Shawn";
      # TODO: Add email
    };

    ellen = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
    };

    jenn = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Jennifer Griffith-Delgado";
        email = "jdg9843@gmail.com";
      };
    };

    zogger = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Pradeep Gollakota";
        email = "pradeepg26@gmail.com";
      };
    };

    vincentpierre = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Vincent Pierre Berges";
        email = "vpsmbb@gmail.com";
      };
    };

    you = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "You Zhou";
        email = "youzhou43@gmail.com";
      };
    };

    yiran = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Yiran Tao";
        email = "yiran@alchemy.com"; # TODO: Confirm
      };
    };

    louisabella = {
      facts.groups = [ "users" ];
      classes = [ ];
      hosts = [ ];
      identity = {
        displayName = "Jei Jiao";
        email = "rabbit721@gmail.com"; # TODO: Confirm
      };
    };
  };
}
