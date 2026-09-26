{ ... }:
{
  imports = [
    ../../modules/alacritty.nix
    ../../modules/base.nix
    ../../modules/claude.nix
    ../../modules/clipboard.nix
    ../../modules/devcontainer.nix
    ../../modules/graphical-session.nix
    ./secrets.nix
    ./ssh.nix
  ];
}
