# Identity-only users (Kanidm/SSO — no Unix accounts, no system-access groups)
_:
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
    };

    taiche = {
      groups = [ "users" ];
      classes = [ ];
      identity.displayName = "Chris";
    };

    jennism = {
      groups = [ "users" ];
      classes = [ ];
      identity.displayName = "Jennifer";
    };

    hugs = {
      groups = [
        "users"
        "grafana.server-admins"
      ];
      classes = [ ];
      identity.displayName = "Shawn";
    };

    ellen = {
      groups = [ "users" ];
      classes = [ ];
    };

    jenn = {
      groups = [ "users" ];
      classes = [ ];
      identity.displayName = "Jennifer";
    };

    tyr = {
      groups = [ "users" ];
      classes = [ ];
    };

    zogger = {
      groups = [ "users" ];
      classes = [ ];
    };

    jess = {
      groups = [ "users" ];
      classes = [ ];
    };

    leo = {
      groups = [ "users" ];
      classes = [ ];
    };

    vincentpierre = {
      groups = [ "users" ];
      classes = [ ];
    };

    you = {
      groups = [ "users" ];
      classes = [ ];
      identity.displayName = "You";
    };

    yiran = {
      groups = [ "users" ];
      classes = [ ];
      identity.displayName = "Yiran";
    };

    louisabella = {
      groups = [ "users" ];
      classes = [ ];
    };
  };
}
