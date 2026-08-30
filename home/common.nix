{
  dotfilesDir,
  username,
  pkgs,
  ...
}:
{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";
  home.sessionPath = [ "${dotfilesDir}/bin" ];

  # Both targets are plain Ubuntu rather than NixOS. Fixes glibc locale
  # warnings and puts Home Manager's data dirs on XDG_DATA_DIRS.
  targets.genericLinux.enable = true;

  home.packages = with pkgs; [
    hello
  ];
}
