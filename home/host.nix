{ link, ... }:
{
  imports = [
    ./claude.nix
    ./languages/c_cpp.nix
    ./languages/python.nix
    ./languages/rust.nix
  ];

  fonts.fontconfig.enable = true;

  xdg.configFile = {
    "alacritty".source = link "config/alacritty";
  };
}
