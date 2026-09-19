{ config, lib, ... }:
let
  # Cloned by hand with the work SSH key, and checked by
  # home/profiles/lely/preflight.sh before any activation is attempted.
  # Keep this in sync with LELY_SECRETS_DIR there.
  lelySecretsDir = "${config.home.homeDirectory}/git/lely/nixfiles-secrets";
  lelyKeysDir = "${lelySecretsDir}/secrets/ssh-keys";

  artifactoryField = key: {
    sopsFile = "${lelySecretsDir}/secrets/artifactory.yaml";
    inherit key;
  };

  # One secret per encrypted file in ssh-keys, deployed under the file's
  # own name. This is the reason for --impure.
  lelyKeys = lib.mapAttrs (name: _: {
    # The whole file is the key; there is no document to index into.
    format = "binary";
    sopsFile = "${lelyKeysDir}/${name}";
    # Place symlink in ~/.ssh.
    path = "${config.home.homeDirectory}/.ssh/${name}";
  }) (lib.filterAttrs (_: type: type == "regular") (builtins.readDir lelyKeysDir));
in
{
  imports = [ ../../modules/secrets.nix ];

  # A string path, not a Nix path literal: the company checkout is read at
  # activation time and never copied into the store, so it never becomes
  # part of this flake and container/personal keep evaluating without it.
  # The price is the eval-time store check, which has to go for every secret
  # in this configuration.
  sops.validateSopsFiles = false;

  # The sops home-manager module is imported by ../../modules/secrets.nix,
  # which ../personal pulls in. This file only adds the work-only secret.
  sops.secrets = lib.mkMerge [
    {
      "gitconfig-lely" = {
        sopsFile = "${lelySecretsDir}/secrets/git.yaml";
      };
      # Named ssh-* so modules/ssh.nix links to it ~/.ssh/lely-config.
      "ssh-lely-config" = {
        sopsFile = "${lelySecretsDir}/secrets/ssh.yaml";
      };
      # Individual fields so that they can be referenced individually.
      "artifactory-machine" = artifactoryField "machine";
      "artifactory-username" = artifactoryField "username";
      "artifactory-password" = artifactoryField "password";
    }
    # Separate definition rather than `//` so that collisions fail loudly.
    lelyKeys
  ];
}
