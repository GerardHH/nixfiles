{ link, ... }:
{
  imports = [
    ./claude.nix
    ./git.nix
    ./languages/c_cpp.nix
    ./languages/python.nix
    ./languages/rust.nix
    ./secrets.nix
  ];

  fonts.fontconfig.enable = true;

  xdg.configFile = {
    "alacritty".source = link "config/alacritty";
  };
}
