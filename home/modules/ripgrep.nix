{
  pkgs,
  link,
  ...
}:
{
  home.packages = with pkgs; [
    ripgrep
  ];

  home.file.".ripgreprc".source = link "config/ripgreprc";
}
