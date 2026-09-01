{
  pkgs,
  link,
  ...
}:
{
  home.packages = with pkgs; [
    btop
    lazygit
  ];

  xdg.configFile = {
    "btop".source = link "config/btop";
    "lazygit".source = link "config/lazygit";
  };
}
