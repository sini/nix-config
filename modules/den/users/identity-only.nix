# Identity-only users (Kanidm/SSO — no Unix accounts, no system-access groups)
{
  den.users.registry = {
    json = {
      groups = [ "admins" ];
      classes = [ ];
    };

    json_user = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Jason-user";
        email = "jason_user@json64.dev";
      };
    };

    greco = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Jason Greco";
        email = "jasonagreco@gmail.com";
      };
    };

    taiche = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Chris Tai";
        email = "christai@gmail.com";
      };
    };

    jennism = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Jennifer Ng";
        email = "jenn.ng@gmail.comm";
      };
    };

    hugs = {
      groups = [
        "users"
        "grafana.server-admins"
      ];
      classes = [ ];
      identity.displayName = "Shawn";
      # TODO: Add email
    };

    ellen = {
      groups = [ "users" ];
      classes = [ ];
    };

    jenn = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Jennifer Griffith-Delgado";
        email = "jdg9843@gmail.com";
      };
    };

    zogger = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Pradeep Gollakota";
        email = "pradeepg26@gmail.com";
      };
    };

    vincentpierre = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Vincent Pierre Berges";
        email = "vpsmbb@gmail.com";
      };
    };

    you = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "You Zhou";
        email = "youzhou43@gmail.com";
      };
    };

    yiran = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Yiran Tao";
        email = "yiran@alchemy.com"; # TODO: Confirm
      };
    };

    louisabella = {
      groups = [ "users" ];
      classes = [ ];
      identity = {
        displayName = "Jei Jiao";
        email = "rabbit721@gmail.com"; # TODO: Confirm
      };
    };
  };
}
