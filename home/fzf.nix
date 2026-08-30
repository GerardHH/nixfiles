{
  pkgs,
  link,
  fzf-tab-completion,
  ...
}:
{
  home.packages = [ pkgs.fzf ];

  xdg.configFile."fzf".source = link "config/fzf";

  xdg.dataFile."fzf-tab-completion".source = fzf-tab-completion;
}
