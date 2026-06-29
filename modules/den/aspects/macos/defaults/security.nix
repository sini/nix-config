# Lock-screen and login security defaults for the laptop.
{
  den.aspects.macos.defaults.security.darwin = {
    # Require the password immediately when the screen saver / display sleep
    # engages — no grace period.
    system.defaults.screensaver = {
      askForPassword = true;
      askForPasswordDelay = 0;
    };

    # No guest account.
    system.defaults.loginwindow.GuestEnabled = false;

    # Dev convenience: skip the "<app> was downloaded from the internet, are you
    # sure you want to open it?" Gatekeeper quarantine prompt. (Loosens that
    # safety check — acceptable on a single-user dev laptop.)
    system.defaults.LaunchServices.LSQuarantine = false;
  };
}
