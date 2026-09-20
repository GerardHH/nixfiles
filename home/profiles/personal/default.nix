{ ... }:
{
  imports = [
    ../../modules/base.nix
    ../../modules/alacritty.nix
    ../../modules/claude.nix
    ../../modules/clipboard.nix
    ../../modules/git.nix
    ../../modules/graphical-session.nix
    ../../modules/languages/c_cpp.nix
    ../../modules/languages/python.nix
    ../../modules/languages/rust.nix
    ./secrets.nix
    ./ssh.nix
  ];
}
