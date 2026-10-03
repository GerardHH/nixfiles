{
    pkgs,
    link,
    ...
}:
{
    home.packages = with pkgs; [
        claude-code
        jq
    ];

    # Link only actuall settings, so that claude-code can dump its own data in .claude folder
    home.file = {
        ".claude/CLAUDE.md".source = link "config/claude/CLAUDE.md";
        ".claude/keybindings.json".source = link "config/claude/keybindings.json";
        ".claude/settings.json".source = link "config/claude/settings.json";
        ".claude/statusline.sh".source = link "config/claude/statusline.sh";
    };
}
