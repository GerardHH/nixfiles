{
  pkgs,
  ...
}:
{
  fonts.fontconfig.enable = true;

  fonts.fontconfig.defaultFonts.monospace = [ "Hack Nerd Font Mono" ];

  home.packages = with pkgs; [
    nerd-fonts.hack
  ];
}
