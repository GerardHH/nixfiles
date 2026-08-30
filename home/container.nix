{ ... }:
{
  # Let Home Manager own the shell here: it writes ~/.bashrc and sources
  # hm-session-vars.sh, so home.packages land on PATH for `devcontainer exec`.
  programs.bash.enable = true;
}
