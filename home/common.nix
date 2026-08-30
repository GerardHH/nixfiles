{
  config,
  dotfilesDir,
  username,
  ...
}:
{
  _module.args.link = path: config.lib.file.mkOutOfStoreSymlink "${dotfilesDir}/${path}";

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "26.05";
  home.sessionPath = [ "${dotfilesDir}/bin" ];

  # Both targets are plain Ubuntu rather than NixOS. Fixes glibc locale
  # warnings and puts Home Manager's data dirs on XDG_DATA_DIRS.
  targets.genericLinux.enable = true;

  xdg.enable = true;
}
