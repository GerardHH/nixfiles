{
  config,
  dotfilesDir,
  lib,
  pkgs,
  ...
}:
let
  fields = [
    "artifactory-machine"
    "artifactory-username"
    "artifactory-password"
  ];

  secretPath = name: config.sops.secrets.${name}.path;

  serverId = "lely";
in
{
  assertions = map (name: {
    assertion = config.sops.secrets ? ${name};
    message = "artifactory.nix needs the sops secret '${name}', which ./secrets.nix does not declare.";
  }) fields;

  home.packages = [ pkgs.jfrog-cli ];

  sops.templates."netrc" = {
    path = "${config.home.homeDirectory}/.netrc";
    mode = "0600";
    content = ''
      machine ${config.sops.placeholder."artifactory-machine"}
      login ${config.sops.placeholder."artifactory-username"}
      password ${config.sops.placeholder."artifactory-password"}
    '';
  };

  # After reloadSystemd, not after sops-nix: the sops-nix entry restarts a
  # unit that linkGeneration has not yet replaced, so it reinstalls the
  # previous generation's secrets. sd-switch in reloadSystemd is what starts
  # the new unit, and only then does a newly added secret exist on disk.
  home.activation.jfrogConfig = lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
    (
      # jfrog-cli comes from the generation being activated, which is not
      # necessarily linked into the profile yet. Subshell so the rest of
      # activation keeps the PATH it had.
      PATH="${lib.makeBinPath [ pkgs.jfrog-cli ]}:$PATH"

      run ${dotfilesDir}/home/profiles/lely/jfrog-config.sh \
        ${serverId} \
        ${secretPath "artifactory-machine"} \
        ${secretPath "artifactory-username"} \
        ${secretPath "artifactory-password"}
    )
  '';
}
