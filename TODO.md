# TODO

- **Inbox:** new thoughts, one bullet each, unsorted. Capture now, sort later.
- **Now:** what I'm working on. One item, two at most.
- **Next:** sorted, top first.
- **Later:** worth keeping, not soon.
- **Stale:** untouched for more than six months, waiting for my review.

Every item carries the date it last changed: in its heading, or at the start of
an Inbox bullet. Bump the date when an item changes. An item older than six
months moves to Stale with its date unchanged. When I review it, it goes back to
another section with today's date, or gets deleted.

Delete an item when it's done; git history keeps it.

## Inbox

- 2026-10-21 · Give Claude Code and Copilot CLI access to language servers
  (clangd, nixd, …), as Copilot has through VSCode: definitions, references and
  diagnostics instead of grep. Claude Code already has an `LSP` tool (fed by
  plugins); check what it needs to use our servers, and whether Copilot CLI has
  the same or can get it through MCP. Ties in with "Copilot CLI in the
  container" in Next.

## Now

### 2026-10-27 · How I take in Claude's changes

The current flow doesn't work well. Claude writes complete files to
`/tmp/claude-1000/<project>/<path in project>` and shows edits as line ranges
in chat (rules in `config/claude/CLAUDE.md`); `claude-diff` and `claude-take`
(`config/bash/claude.sh`) review and copy them in. With neotest-testmate I
took the changes into the repo first and reviewed them there instead. Now that
I'm more at ease with Claude, look for a better way.

Keep: only results land in the repo, Claude's experiments stay in `/tmp`, and
Claude can still write only there. To explore:

- Handing changes over: like git conflicts (markers in the repo file, resolved
  with git-conflict.nvim, see its item in Next), or other ways, e.g. a git
  branch or worktree under `/tmp` that I fetch from. Likely makes
  `config/bash/claude.sh` unneeded; the `TODO.md` working copy goes through it
  too.
- Explaining changes: Claude's chat output going into detail on each change,
  inline comments in the code, or both.
- Drop the per-project write denial. Check which entry that is in
  `config/claude/settings.json`: `sandbox.filesystem.denyWrite` has both `~`
  and `~/nixfiles`, and `permissions.deny` has `Edit(~/**)`.
- Rewrite the rules in `config/claude/CLAUDE.md` to match what we pick.

## Next

### 2026-10-04 · setlocale warnings in the work container

bash warns it cannot set `en_US.UTF-8` (LC_CTYPE, LC_COLLATE). Our config sets
no `LANG`; the image's glibc has no such locale, and `LOCALE_ARCHIVE_2_27` only
helps nix programs. Find where `LANG` comes from (image `ENV`, devcontainer.json
`containerEnv`/`remoteEnv`), then e.g. `--remote-env LANG=C.UTF-8` in
`bin/nix-devcontainer.sh`.

### 2026-10-03 · Copilot CLI in the container

Needed for work; Claude Code covers it for now. Open question: deliver the token
through `nixfiles-secrets` (sops) so a container rebuild costs nothing. Likely
shape: a token on the host from sops, passed in by `bin/nix-devcontainer.sh` as
an environment variable or bind-mounted file, like the per-workspace bash
history mount there.

### 2026-10-05 · git-conflict.nvim breaks on nvim 0.12

Opening a file with merge conflicts errors in nvim:
`git-conflict.lua:655: attempt to call field 'disable' (a nil value)`, from the
`GitConflictDetected` autocmd. git-conflict.nvim (a1badcd) still calls
`vim.diagnostic.disable(bufnr)`, which nvim 0.12 removed; our
`disable_diagnostics = true` in `config/nvim/lua/plugins/git.lua` triggers it.
Resolving a conflict (`<leader>gct`, then saving) fails too, at
`git-conflict.lua:665` in `GitConflictResolved`:
`enable: expected boolean, got number`, as it calls the old
`vim.diagnostic.enable(bufnr)`. It fires once from `choose` and again from the
later re-parse (`process`, line 673). Goal beyond the error: hide errors and
warnings while a buffer has conflict markers, as they clutter the conflict and
make it harder to read; the markers alone already break the parse, so the
diagnostics are mostly noise. Fix: set `disable_diagnostics = false` and do it
ourselves from those two autocmds with
`vim.diagnostic.enable(false, { bufnr = … })` and
`vim.diagnostic.enable(true, { bufnr = … })`, or find a maintained fork. Check
that diagnostics come back after the last conflict is resolved.

### 2026-10-08 · Log podman in to the work registry

Log podman in to the work registry automatically, so pulls in
`bin/nix-devcontainer.sh` don't need a manual `podman login`. Rootless podman
keeps logins in `$XDG_RUNTIME_DIR/containers/auth.json` (tmpfs), so they're gone
after a reboot. The work profile already has the credentials as sops secrets
(`artifactory-machine`, `-username`, `-password` in
`home/profiles/lely/artifactory.nix`), so no new secret is needed if the
registry is that Artifactory. Options: a `credHelpers` entry in
`~/.config/containers/auth.json` naming a small `docker-credential-<name>`
script that prints the sops secrets on demand (nothing stored, podman asks when
needed); or a systemd user unit / activation step running
`podman login --authfile … --password-stdin`. A sops template can't write
`auth.json` itself, as its `auth` field is base64 of `user:password`. Check
first which registry the work images come from.

### 2026-10-04 · Wierd drawing in gutter

Container only: opening a `.cpp` file (test or not) the first time puts `TEST`
in the sign column; line numbers overwrite it only partly, and closing and
reopening the buffer brings it back. Next time, find the owner with
`:lua =vim.api.nvim_buf_get_extmarks(0, -1, 0, -1, { details = true, type = "sign" })`.
Suspect: todo-comments, whose highlight pattern `.*<(KEYWORDS)\s*` needs no `:`
and so matches `TEST` in `TEST_CASE`, before treesitter can tell it isn't a
comment. The leftover remnants hint at a glyph that nvim and the terminal draw
at different widths (the container forces `TERM=xterm-256color`).

### 2026-10-15 · nvim plugins through nix

Install plugins from nixpkgs-unstable instead of lazy.nvim's git clones. Either
way: nix decides what exists (plugins, store paths, per-profile flags, via the
generated `nix_languages.lua`); Lua keeps all behaviour, simple opts too, and
stays a linked `config/nvim`. Language plugins (rustaceanvim, SchemaStore.nvim)
could go in `languages.<name>.plugins`. Drop `build` in `blink.cmp.lua` and the
rust toolchain in `nvim.nix`. nixpkgs' nvim-treesitter already follows `main`.
Not nixvim/nvf (config in nix); nixCats-nvim is the same idea as a framework.

1. **Decide first: keep lazy.nvim, or drop it in the same move.** Once nix
   installs the plugins, lazy.nvim mostly just loads them. Dropping it can
   also be split off into its own item, but decide here, before building
   anything lazy-specific.
   - **With lazy.nvim:** keep the per-topic specs in
     `config/nvim/lua/plugins/`. `home/modules/nvim.nix` builds a `linkFarm`
     keyed by lazy's plugin name (repo basename or `name`: `catppuccin`,
     `blink.cmp`; the nixpkgs attrs differ: `catppuccin-nvim`, `blink-cmp`),
     next to `NVIM_NIX_RUNTIME`. `init.lua` points lazy's
     `dev = { path, patterns = { "" }, fallback = true }` at it, so plugins
     not in nix yet still clone. `neotest-testmate` stays a `dir =` plugin.
   - **Without lazy.nvim:** nix puts its plugins on the packpath
     (`pack/nix/{start,opt}`), and plugins not in nix come from nvim 0.12's
     own `vim.pack`. Move to nvim's standard layout: `plugin/` for setup,
     `lua/` for modules, `lsp/<server>.lua` for server configs,
     `after/ftplugin/<ft>.lua` per filetype. Open: start LSP from
     `after/ftplugin` per filetype, or generically with `vim.lsp.enable` over
     the servers in `nix_languages.lua`. Lazy-loading by hand where it
     matters (`opt` + `packadd` on an event or key; lz.n if that grows).
     What the lazy specs do now (`keys`, `opts`, `dependencies`, `ft`/`cmd`
     triggers) moves into plain Lua. The language support in
     `home/modules/languages/` (`languages.<name>.packages`, the generated
     manifest, `NVIM_NIX_RUNTIME`) changes with it.

### 2026-10-07 · tmux plugins through nix

Replace tpm (`~/.tmux/plugins`) with nix-installed plugins, with the same split
as the nvim item: `config/tmux/tmux.conf` stays a linked file (all `@options`
and behaviour, reloadable with `source-file`). Nix writes one
`run-shell <plugin>.rtp` line per plugin to
`~/.local/share/tmux-nix/plugins.conf`, which `tmux.conf` sources with
`source-file -q` where tpm's `run` is now. Not home-manager's `programs.tmux`:
config in nix strings, tmux-sensible on top unless `sensibleOnTop = false`, and
its `tmux.conf` clashes with the linked `config/tmux` directory. nixpkgs has
`tmuxPlugins.tmux-which-key` (pyyaml wrapped in; our
`@tmux-which-key-xdg-enable` already keeps its generated `init.tmux` out of the
plugin dir). It has no dreamsofcode-io/catppuccin-tmux: package the fork with
`mkTmuxPlugin` (`rtpFilePath = "catppuccin.tmux"`; it only reads its own dir),
or move to `tmuxPlugins.catppuccin` (official v2: `@catppuccin_flavor`, status
line set up by hand).

## Later

### 2026-10-26 · Publish neotest-testmate as a plugin

After it has proven itself at work. `config/nvim/local-plugins/neotest-testmate/`
is a neotest adapter that runs C++ test executables directly, like VSCode's C++
TestMate, instead of through CTest, with nvim-dap for debug runs. Supports
Catch2 v2/v3 and GTest/GMock (`catch2.lua`, `gtest.lua`, `xml.lua`; framework
picked by `#include`). Fixtures in its `tests/fixtures/`: `cmake-catch2`
(Catch2 v3) and `colcon` (a colcon workspace: Catch2 v2, GTest in
`src/toolbox/greeter`, and there also a Catch2 test that mocks with GMock,
`greeter_catch2_test.cpp`). Each has a `*crash_test*` executable that crashes
on purpose, for `tests/unit/crash_spec.lua`. Keep work project details out of
this repo; facts only.

Specs (plenary busted; `tests/unit` calls the adapter, `tests/integration` runs
neotest itself, `tests/suite` is a `<leader>tp` run of `colcon`) run where the
fixtures were built, as the adapter finds an executable by the source paths in
it: in the plugin's own container (`.devcontainer/`, with the tools every
fixture builds with, and ptrace for codelldb). From `~/nixfiles`:
`bin/nix-devcontainer.sh config/nvim/local-plugins/neotest-testmate -- make check`
(deps, fixtures, specs); in the container's shell, `make check`, or `make test`
to rerun the specs only. In Claude's sandbox the fixtures must be on a writable
path: neotest's `lib.files.exists` uses `os.rename(path, path)`, which fails on
the read-only repo (EROFS), so discovery silently finds nothing. So Claude
builds a scratch copy of the plugin in the session scratchpad, `colcon`'s
packages by plain CMake (no colcon on the host), and runs `make test` there
(configure offline with `-DFETCHCONTENT_SOURCE_DIR_CATCH2=` and `_GOOGLETEST=`
the repo builds' `_deps/*-src`). DEBUG log for a run:
`:lua require("neotest.logging"):set_level("debug")`, then
`~/.local/state/nvim/neotest.log`.

To look into, to make it a proper plugin:

- Own repo, and a name: "TestMate" is someone else's VSCode extension.
- Drop the neotest-ctest dependency by vendoring its Catch2 query, its only
  remaining use.
- Configuration: the options in `init.lua` (`build_dirs`, `executable_glob`,
  `dap_adapter`, `break_on_failure`, through `adapter.setup`). Are they the
  right ones, validated (`vim.validate`) and documented? What else a project
  may need, e.g. other build layouts, environment variables or extra
  arguments for the run.
- Other OSes: macOS and Windows. Linux-isms to check: the executable-bit test
  in `find_executable` (Windows has none; executables end in `.exe`), exit
  code 128 + signal (`exit.lua`), the loader's 127 and `install/setup.bash`
  in `exit_hints`, and path separators.
- CI for the specs: `make check` in `.devcontainer/`, e.g. with GitHub's
  `devcontainers/ci`. The image then needs nvim, ripgrep, a C++ parser and
  codelldb (for `tests/integration/debug_spec.lua`) itself, which
  `bin/nix-devcontainer.sh` brings from nixfiles now. Then a matrix over the
  OSes above and nvim stable/nightly; outside the container the fixtures need
  their own toolchain, and colcon only exists on Linux.
- Test the claim that Catch2 v2/v3 is supported, beyond the two versions the
  fixtures pin.
- Plugin basics: README (install, setup, options), vimdoc in `doc/`,
  `:checkhealth` (ripgrep, the C++ parser, nvim-dap and the dap adapter),
  LICENSE, the minimum nvim version, tagged releases with a changelog (maybe
  luarocks), and lint in CI (stylua, lua-language-server type checks).

### 2026-10-16 · `install.sh`: skip the switch when nothing changed

Now that `bin/nix-devcontainer.sh` keeps the container, it still runs
`install.sh` on every start, and `hm_switch` (`lib/nix.sh`) runs a full
`home-manager switch` each time. Skip it when the profile is already current.
Either in `install.sh`: compare the store path of the profile's activation
package (`nix eval --raw` of `homeConfigurations.<profile>.activationPackage`,
an evaluation without a build) with the active Home Manager generation (check
where it keeps that link on this setup). Or in `nix-devcontainer.sh`: skip
`install.sh` for a reused container, if `devcontainer up`'s JSON output tells a
reused container from a new one (check). The first also covers a changed
nixfiles checkout.

Also its last line, "Done. Open a new shell, then rebuild with:
'nix-switch.sh'", reads as two required steps. No rebuild is needed: `hm_switch`
already activated the profile; `nix-switch.sh` is for later changes. In the
container, `nix-devcontainer.sh` already drops into a new shell. Open: on a
fresh host, the shell that ran `install.sh` lacks the new PATH and bashrc, so
"open a new shell" may still be needed there. Check, then reword it, or leave it
out where it isn't needed.

### 2026-10-16 · Completion for `bin/nix-devcontainer.sh`

Bash completion for its arguments: the workspace folder (directories with a
`.devcontainer/`), then `devcontainer up`'s own options, which it forwards
(`--remove-existing-container` among them).

### 2026-10-06 · nixd completion for our own options

nixd completion and hover docs for our own options, such as
`languages.<name>.packages` from `home/modules/languages/default.nix`. Likely
set up already: `config/nvim/lua/plugins/lsp.lua` points nixd's
`options.home-manager` at `homeConfigurations.<personal|container>.options` of
`~/nixfiles`, which holds our options next to home-manager's. Check whether it
works in e.g. `home/modules/languages/nix.nix`, and whether the
`attrsOf submodule` under `languages` gets completion. If not, see `:LspLog`,
and whether files outside the configuration's entry point need their own options
expression.

### 2026-10-15 · Smoke test after `bin/nix-update.sh`

One script with a section per program, each failing loudly when a nixpkgs bump
breaks our config. Open: a separate `bin/` script or a step at the end of
`nix-update.sh`; run in the container too (skip what the profile lacks).
Sections, most valuable first:

- nvim: `nvim --headless`, open a sample file per language, fail on startup
  errors (`v:errmsg`, `:messages`), lazy.nvim plugins that failed to load, LSP
  clients that didn't attach (covers `languages.<name>.packages`; `--version` on
  each as a fallback), and errors from `:checkhealth`. It should catch the
  git-conflict.nvim break in Next (nvim 0.12 removed `vim.diagnostic.disable`),
  which needs a file with conflict markers. The neotest-testmate specs (`tests/`
  and `Makefile` in its directory) show the setup: headless nvim, sandboxed XDG
  directories.
- bash: `bash --login -i -c exit` with empty stderr. Covers the `config/bashrc`
  integrations: navi, zoxide, oh-my-posh (`theme.toml`), carapace,
  bash-completion, `fzf/fzf.sh`, fzf-tab-completion.
- tmux: `tmux -L smoketest new-session -d`, check `show-messages` for config
  errors, then `kill-server`. Covers tpm plugins (tmux-which-key needs pyyaml),
  and the nix-installed ones once "tmux plugins through nix" lands.
- Other profiles: `nix build --dry-run` of
  `homeConfigurations.<profile>.activationPackage` for each profile, as
  `nix-update.sh` only builds the active one. Flake `checks` (none yet) would be
  the natural home.
- Links and secrets: no dangling links under `~/.ssh` (sops-nix failed to
  decrypt), `~/.config` or `~/.claude` (a `link "config/…"` target moved);
  `ssh -G <host>` parses the generated config.
- git: `git config --list` parses (lely guard include too);
  `git -c core.pager=delta log -p -1 | cat` runs delta with our config. lazygit
  can't check its config headless; `--version` only.
- Claude Code: `jq empty` on `settings.json` and `keybindings.json`; piping
  `{"vim":{"mode":"INSERT"}}` into `statusline.sh` prints `-- INSERT --`.
- devcontainer: `devcontainer --version` (the docker → `emptyDirectory` override
  in `devcontainer.nix` is fragile across bumps).
- alacritty (personal, lely): the nixGL wrapper is the fragile part, and
  `--version` doesn't touch GL; `alacritty -e true` in the graphical session.

### 2026-10-16 · Nested tmux in the container

The container shell runs in a host tmux pane (every alacritty window starts in
tmux, group `main`, via `[terminal.shell]` in
`config/alacritty/alacritty.toml`), so tmux inside it is nested (prefix clash,
two status lines). Nothing starts tmux in the container. Options: don't run it
there, or give the inner one a different prefix, or a key that turns the outer
one off so keys pass through.

Alternative to tmux as the multiplexer: nvim with `:terminal` buffers for
shells, and its sessions for layout. One less layer and one set of keys, but
shells die with nvim.

### 2026-10-04 · Pasting host → container only works with Ctrl+Shift+V

(the terminal's own paste), not with nvim's `p` or the middle mouse button. By
design for now: without wl-copy/xclip, `config/nvim/lua/options/clipboard.lua`
copies through OSC 52 but serves `+`/`*` pastes from register 0, because
terminals refuse OSC 52 reads. With `mouse` on, a middle click goes to nvim,
which pastes `*`; Shift+middle click is the terminal's own primary paste.
Options: bind-mount the Wayland socket and add wl-clipboard in the container, or
let tmux answer OSC 52 reads.

### 2026-10-03 · fzf bash completion after any command

`**<Tab>` only triggers for commands it knows, e.g. not after
`tmux source-file`. Goal: path completion after any command, and bash completion
for tmux.

### 2026-10-04 · nvim plugins to evaluate

- nvim-hlslens: match index next to search results.
- blink-ripgrep.nvim: blink.cmp source with words from the whole project.
- treesj: split/join on treesitter nodes; overlaps mini.splitjoin.
- tiny-inline-diagnostic.nvim: nicer inline diagnostics.
- quicker.nvim: editable, nicer quickfix list.
- nvim-chainsaw: insert and remove log statements.

### 2026-10-04 · Code-aware spell checker in nvim

Baseline without installs: `:set spell`, which with treesitter only checks
comments and strings. Candidates, all in nixpkgs with an nvim-lspconfig config:
codebook (tree-sitter based, splits identifiers like `camelCase`), typos-lsp
(list of known misspellings, few false positives), harper (spelling and grammar
in comments and Markdown). ltex-ls-plus (LanguageTool) is heavier, on a JRE.

### 2026-10-03 · TUIs to look into

- TUIOS: window manager inside the terminal.
- superfile: file manager; compare with yazi, which is in use now.

### 2026-10-13 · Merge nvim's statusline into the tmux status

Show nvim's statusline (lualine, `config/nvim/lua/plugins/lualine.lua`) in the
tmux status, which already sits at the top (`status-position top` in
`config/tmux/tmux.conf`), so nvim needs no status line of its own. The empty
line under nvim's statusline is the command line; `cmdheight=0` hides it with
any option below. Options:

- vim-tpipeline: evaluates the current window's `statusline` (lualine works,
  nvim-recorder's slots in it too) and writes it into the tmux status, then
  sets `laststatus=0`. Needs `focus-events on`. Its autoembed takes over
  `status-left`/`status-right`, which catppuccin-tmux fills now; else
  `g:tpipeline_autoembed = 0` and put its `#(cat …vimbridge)` in our own
  status format. Splits lose their own status line (lualine has no
  `globalstatus` now); a `winbar` with the file name covers that. Check what
  the status shows when the focus moves to a pane without nvim.
- Own bridge, no plugin: autocmds (`ModeChanged`, `BufEnter`,
  `DiagnosticChanged`, …) run `tmux set-option -p @nvim_mode …` for
  `$TMUX_PANE`, the status format shows `#{@nvim_mode}` in tmux's own styles,
  and `VimLeave` unsets them. Full control, but each field built by hand.
- Terminal title: nvim's `title`/`titlestring` sets the pane title, which the
  status shows with `#{pane_title}`. Plain text, no colours; least work.
- Without tmux: lualine as `tabline`/`winbar`, `laststatus=0`,
  `cmdheight=0`. At the top too, but beside the tmux status, not merged.
- Matching only, not merging: tmuxline.vim generates a tmux status in the
  statusline's colours; catppuccin on both sides already gives that.

### 2026-10-03 · Window manager: noctalia

Look into noctalia when picking a window manager (the Super layer); maybe after
moving to NixOS, maybe not.

### 2026-10-03 · `<leader>ba` fails on terminal buffers

Overseer related; overseer is disabled for now (`enabled = false` in
`config/nvim/lua/plugins/task.lua`). The error went away after an nvim restart,
so whether overseer opened the terminal is still open. Cause not found:
overseer's own task buffers are unlisted scratch buffers from `nvim_open_term`,
while the `term://…:/usr/bin/sh` name is what `:terminal` with shell
`/usr/bin/sh` produces. `%bd` stops at the first buffer `:bdelete` refuses (E89:
a terminal with a running job, or a modified buffer), so the current buffer
stays open too; `<leader>bo` (`%bd | e# | bd#`) breaks the same way. Fix drafted
(not applied): a `delete_buffers(keep)` helper in `config/nvim/lua/keymaps.lua`
that runs `pcall(vim.cmd.bdelete, buf)` on each listed buffer, current one last,
and lists what it kept. Recommended: skip refused buffers rather than
force-delete.

### 2026-10-03 · Register each test case with CTest (for the team)

`catch_discover_tests` / `gtest_discover_tests` gives per-test results in
ctest/colcon/CI, crash isolation, `--rerun-failed` and `-j`. At work, CTest now
knows one test per package (plain `add_test`). Catch2 v2 can only discover at
build time, so the executable must start during `colcon build`.

## Stale
