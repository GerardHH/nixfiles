{
  pkgs,
  link,
  ...
}:
{
  imports = [
    ./fzf.nix
  ];

  home.packages = with pkgs; [
    bat
    eza
    navi
    oh-my-posh
    tmux
    zoxide
  ];

  home.file.".bashrc".source = link "config/bashrc";

  xdg.configFile = {
    "bash".source = link "config/bash";
    "navi".source = link "config/navi";
    "oh-my-posh".source = link "config/oh-my-posh";
    "tmux".source = link "config/tmux";
  };
}
