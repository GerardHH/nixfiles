{ pkgs, link, ... }:
{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    nixd
    nixfmt
  ];

  xdg.configFile = {
    "alacritty".source = link "config/alacritty";
  };
}
