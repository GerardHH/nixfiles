{ link, ... }:
{
  imports = [
    ../../modules/base.nix
    ../../modules/claude.nix
    ../../modules/git.nix
    ../../modules/languages/c_cpp.nix
    ../../modules/languages/python.nix
    ../../modules/languages/rust.nix
    ../../modules/secrets.nix
  ];

  fonts.fontconfig.enable = true;

  xdg.configFile = {
    "alacritty".source = link "config/alacritty";
  };
}
