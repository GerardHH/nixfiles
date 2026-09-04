{
  pkgs,
  link,
  ...
}:
{
  home.packages = with pkgs; [
    lazygit
    delta
  ];

  xdg.configFile = {
    "lazygit".source = link "config/lazygit";
  };
}
