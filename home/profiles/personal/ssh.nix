{ config, lib, ... }:
{
  # Fail evaluation rather than emit a Host block pointing at a key that was
  # never deployed. ssh would just fail to authenticate, with nothing tying
  # the symptom back to a missing secret declaration.
  assertions = [
    {
      assertion = config.sops.secrets ? "ssh-github-personal";
      message = "home/profiles/personal/ssh.nix points at ~/.ssh/github-personal, but no sops secret 'ssh-github-personal' is declared in ../../modules/secrets.nix.";
    }
  ];
  # IdentitiesOnly is set per host, not globally: a `Host *` block setting it
  # would stop ssh offering the default keys to hosts declared nowhere here.
  my.ssh.config = lib.mkOrder 1000 ''
    Host github.com
      User git
      IdentityFile ~/.ssh/personal-key
      IdentitiesOnly yes
  '';
}
