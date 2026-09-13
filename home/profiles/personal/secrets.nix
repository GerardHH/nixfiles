{
  ...
}:
{
  imports = [ ../../modules/secrets.nix ];

  # Leaving `path` unset puts the decrypted file at ~/.config/sops-nix/secrets
  sops.secrets = {
    "ssh-github-personal" = {
      sopsFile = ../../../secrets/ssh.yaml;
    };
  };
}
