{ ... }:
{
  # The sops home-manager module is imported by ../../modules/secrets.nix,
  # which ../personal pulls in. This file only adds the work-only secret.
  sops.secrets."gitconfig-lely" = {
    sopsFile = ../../../secrets/git.yaml;
  };
}
