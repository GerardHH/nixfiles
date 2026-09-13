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
  };
}
