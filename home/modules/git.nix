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

  home.file = {
    ".gitconfig".source = link "config/git/gitconfig";
  };

  xdg.configFile = {
    "lazygit".source = link "config/lazygit";
    "git/gitconfig-lely-guard".source = link "config/git/gitconfig-lely-guard";
  };
}
