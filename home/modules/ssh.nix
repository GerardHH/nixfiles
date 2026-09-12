{ config, lib, ... }:
let
  # Every sops secret named ssh-<name> is turned into ~/.ssh/<name>, so all
  # ssh material is findable in one directory and the config can refer to
  # ~/.ssh paths instead of sops-nix internals. Adding a key to a profile's
  # sops.secrets is enough; nothing here needs changing.
  sshSecrets = lib.filterAttrs (name: _: lib.hasPrefix "ssh-" name) config.sops.secrets;

  secretLinks = lib.mapAttrs' (
    name: secret:
    lib.nameValuePair ".ssh/${lib.removePrefix "ssh-" name}" {
      source = config.lib.file.mkOutOfStoreSymlink secret.path;
    }
  ) sshSecrets;
in
{
  options.my.ssh.config = lib.mkOption {
    type = lib.types.lines;
    default = "";
    description = ''
      Contents of ~/.ssh/config, concatenated from every module that sets it.

      Order is significant, because ssh uses the FIRST value it obtains for
      any given option rather than the last. Place blocks with lib.mkOrder:
      Includes early, specific Host blocks next, `Host *` last via mkAfter.
    '';
  };

  config = {
    assertions = [
      {
        assertion = !(sshSecrets ? "ssh-config");
        message = "A sops secret named 'ssh-config' would collide with the generated ~/.ssh/config.";
      }
    ];

    # Not programs.ssh: Gives no control over block order. home.file manages
    # these paths only, so ~/.ssh stays an ordinary directory other tools can
    # still write to, including for keys placed by hand.
    home.file = secretLinks // {
      ".ssh/config" = lib.mkIf (config.my.ssh.config != "") { text = config.my.ssh.config; };
    };

    # Hand-edited escape hatch, first so it can pre-empt anything generated.
    # The generated file is a read-only store symlink, so this is the only
    # way to override it in place. ssh silently ignores an Include whose
    # target is missing, so it costs nothing when the file does not exist.
    my.ssh.config = lib.mkOrder 400 ''
      Include ~/.ssh/config.local
    '';
  };
}
