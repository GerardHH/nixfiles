{ config, ... }:
let
  # Cloned by hand with the work SSH key, and checked by
  # home/profiles/lely/preflight.sh before any activation is attempted.
  # Keep this in sync with LELY_SECRETS_DIR there.
  lelySecretsDir = "${config.home.homeDirectory}/git/lely/nixfiles-secrets";
in
{
  # A string path, not a Nix path literal: the company checkout is read at
  # activation time and never copied into the store, so it never becomes
  # part of this flake and container/personal keep evaluating without it.
  # The price is the eval-time store check, which has to go for every secret
  # in this configuration.
  sops.validateSopsFiles = false;

  # The sops home-manager module is imported by ../../modules/secrets.nix,
  # which ../personal pulls in. This file only adds the work-only secret.
  sops.secrets = {
    "gitconfig-lely" = {
      sopsFile = "${lelySecretsDir}/secrets/git.yaml";
    };
    # Named ssh-* so modules/ssh.nix links to it ~/.ssh/lely-config.
    "ssh-lely-config" = {
      sopsFile = "${lelySecretsDir}/secrets/ssh.yaml";
    };
  };
}
