{ ... }:
{
  imports = [
    ../../modules/base.nix
    ../../modules/alacritty.nix
    ../../modules/claude.nix
    ../../modules/clipboard.nix
    ../../modules/git.nix
    ../../modules/graphical-session.nix
    ./secrets.nix
    ./ssh.nix
  ];
}
