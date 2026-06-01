{ den, ... }:
{
  den.aspects.pol = {
    includes = [ den.aspects.roles.default ];
  };

  den.users.registry.pol = {
    system.uid = 1005;
    groups = [
      "users"
      "server-access"
      "grafana.server-admins"
      "open-webui.admins"
    ];
    identity = {
      displayName = "Pol Dellaiera";
      email = "pol@json64.dev";
      sshKeys = [
        {
          tag = "a";
          key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDfxTd6cA45DZPJsk3TmFmRPu1NQQ0XX0kow18mqFsLLaxiUQX1gsfW1kTVRGNh4s77StdsmnU/5oSQEXE6D8p3uEWCwNL74Sf4Lz4UyzSrsjyEEhNTQJromlgrVkf7N3wvEOakSZJICcpl05Z3UeResnkuZGSQ6zDVAKcB3KP1uYbR4SQGmWLHI1meznRkTDM5wHoiyWJnGpQjYVsRZT4LTUJwfhildAOx6ZIZUTsJrl35L2S81E6bv696CVGPvxV+PGbwGTavMYXfrSW4pqCnDPhQCLElQS4Od1qMicfYRSmk/W2oAKb8HZwFoWQSFUStF8ldQRnPyn2wiBQnhxnczt2jUhq1Uj6Nkq/edb1Ywgn7jlBR4BgRLD3K3oMvzJ/d3xDHjU56jc5lCA6lFLDMBV6Q9DKzMwL2jG3aQbehbUwTz7zbUwAHlCFIY5HGs4d9veXHyCsUikCLPvHL/hQU/vFRHHB7WNEyQJZK+ieOAW+un+1eF88iyKsOXE9y8PjLvXYcPHdzGaQKnqzEJSQcTUw9QSzOZQQpmpy8z6Lf08D2I4GHq1REp6d4krJOOW0gXadjsGEhLqQqWGnHE47QBPnlHlDWzOaf3UX59rFsl8xZDXoXzzwJ1stpeJx+Tn/uSNnaf44yXFyeFK/IDUeOrXYD4fSTLP1P/lCFCfeYqw== a@github.com";
        }
        {
          tag = "b";
          key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDCinYKlfRgeENAcDBxSlvsp7FMUWexYiOaY3hx3jbV947d+UGsufNvdmqMUbHg2f57ywaOY01uWAGd3tzpVnr2+OrjprXfEymvJBxBUSiK5ks6Jst2fs2LqQmr3bNVt0yWNEv/WQtGEj7eEjIY2cnJ8lmMaebv+WMg+Kb/Tw5hdaGeit2nPwQJGS4nQ+XBtPlqzaGmlm1/JRcBFkReoODRWPD7WrGTq4IpKl8k27Dui8LOS5pwIJm8L/k6G7f7eKt+GvtNkqN8TvArck86AYfHWWfy5rYNylbfk2djkVDKDnV65zUUo7ztnNEGdAOb3wV3KZOzJrgZ4ojfgMSwKh8D b@github.com";
        }
        {
          tag = "c";
          key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAnGjEjo6YGg4cGEHi+GpZuL3nKbrCln4IfRzsoPOnhv c@github.com";
        }
      ];
    };
  };
}
