{
  pkgs,
  link,
  ...
}:
{
  home.packages = with pkgs; [
    claude-code
  ];

  # Link only actuall settings, so that claude-code can dump its own data in .claude folder
  home.file = {
    ".claude/settings.json".source = link "/config/claude/settings.json";
    ".claude/CLAUDE.md".source = link "config/claude/CLAUDE.md";
  };
}
