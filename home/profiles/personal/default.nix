{ link, ... }:
{
  imports = [
    ../../modules/base.nix
    ../../modules/claude.nix
    ../../modules/git.nix
    ../../modules/languages/c_cpp.nix
    ../../modules/languages/python.nix
    ../../modules/languages/rust.nix
    ./secrets.nix
    ./ssh.nix
  ];

  xdg.configFile = {
    "alacritty".source = link "config/alacritty";
  };
}
