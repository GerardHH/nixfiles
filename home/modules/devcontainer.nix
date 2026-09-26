{
  pkgs,
  ...
}:
{
  # Don't pull in docker.
  # Consequence: devcontainer has to be build with `yarn`.
  home.packages = with pkgs; [
    (devcontainer.override {
      docker = emptyDirectory;
      docker-compose = emptyDirectory;
    })
  ];
}
