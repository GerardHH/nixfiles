{ config, lib, ... }:
{
  # Fail evaluation rather than emit an Include that ssh will silently
  # ignore. A missing fragment is graceful degradation on a machine without
  # company secrets, but on this profile it is a mistake.
  assertions = [
    {
      assertion = config.sops.secrets ? "ssh-lely-config";
      message = "home/profiles/lely/ssh.nix Includes ~/.ssh/lely-config, but no sops secret 'ssh-lely-config' is declared in ./secrets.nix.";
    }
  ];

  # Only an Include. The work hosts can never be inlined here: this repo is
  # public, and a Nix string would land in the world-readable store even if
  # it were not. The fragment carries its own Host blocks and IdentityFile
  # lines, pointing at ~/.ssh paths that modules/ssh.nix links into place.
  #
  # mkBefore is order 500: after the escape hatch at 400, before the
  # personal Host blocks at 1000.
  my.ssh.config = lib.mkBefore ''
    Include ~/.ssh/lely-config
  '';
}
