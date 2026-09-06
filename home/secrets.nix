{
  config,
  pkgs,
  sops-nix,
  ...
}:
{
  imports = [ sops-nix.homeManagerModules.sops ];

  home.packages = with pkgs; [
    sops
    age
  ];

  sops = {
    age.keyFile = "${config.xdg.configHome}/sops/age/keys.txt";

    # Leaving `path` unset puts the decrypted file at ~/.config/sops-nix/secrets
    secrets = {
      "gitconfig-lely" = {
        sopsFile = ../secrets/git.yaml;
      };
      "personal" = {
        sopsFile = ../secrets/ssh.yaml;
      };
    };
  };
}
