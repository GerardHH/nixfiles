{ pkgs, ... }:
{
  # rustaceanvim drives this; the toolchain itself (cargo, rustc) is expected
  # to come from the project, via rustup or a devshell.
  home.packages = [ pkgs.rust-analyzer ];
}
