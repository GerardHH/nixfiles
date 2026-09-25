{ pkgs, ... }:
{
  languages.nix = {
    packages = with pkgs; [
      nixd
      nixfmt
    ];
    servers = [ "nixd" ];
  };
}
