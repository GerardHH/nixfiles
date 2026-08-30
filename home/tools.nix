{
  pkgs,
  link,
  ...
}:
{
  home.packages = with pkgs; [
    lazygit
  ];

  xdg.configFile = {
    "lazygit".source = link "config/lazygit";
  };
}
