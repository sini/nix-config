{ rootPath, ... }:
{
  den.aspects.applications.dev.security.signing-key = {
    homeManager =
      { user, config, ... }:
      {
        age.secrets.user-signing-key = {
          rekeyFile = rootPath + "/.secrets/users/${user.name}/id_signing.age";
          mode = "600";
          generator.script = "shared-ssh-key";
          # agenix's home-manager default path is a *shell string*, not a path:
          # "$(<store>/bin/getconf DARWIN_USER_TEMP_DIR)/agenix/<name>" on darwin
          # and "${XDG_RUNTIME_DIR}/agenix/<name>" on linux. It only resolves
          # inside a shell (agenix's own activation script, the ssh-agent-mux
          # wrapper). Written into a config file that is not shell-expanded it is
          # taken literally, and ssh_config does neither substitution: the darwin
          # form splits on the space inside the command substitution ("keyword
          # identityfile extra arguments at end of line", fatal) and the linux
          # form is looked up as a directory named `${XDG_RUNTIME_DIR}`, which
          # silently never matches. Pin a real static path instead — agenix
          # symlinks it onto the decrypted secret during activation.
          path = "${config.home.homeDirectory}/.ssh/id_signing";
        };
      };
  };
}
