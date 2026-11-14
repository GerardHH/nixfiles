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

- 2026-11-14 · Sandbox read denials with a leading `**` don't work on Linux:
  `Read(//**/.env)` and `Read(//**/secrets.d/**)` in
  `config/claude/settings.json` stop the Read tool only; a sandboxed `cat` of
  a `.env` succeeds (tested). Linux takes a wildcard only after the first
  directory name, so e.g. `~/**/.env`, `/run/**/secrets.d`; check which
  paths matter.

## Now

### 2026-11-14 · How I take in changes from Claude and Copilot

The old flow, proposals in `/tmp/claude-1000` taken in with `claude-diff` and
`claude-take` (`config/bash/claude.sh`), didn't work well. Easy path first
(proposed 2026-11-14): Claude writes in the project, I review through git.

- `config/claude/settings.json`: `Edit(~/**)` and the sandbox's `~` and
  `~/nixfiles` write denials gone (a `denyWrite` entry overrides the working
  directory's default write access, so `~` had to go too);
  `blockWritesOutsideWorkingDirectories` keeps the Edit tool in the project
  and `/tmp/claude-1000` (`additionalDirectories`). `.git` stays writable
  for now: "don't stage or commit" is a rule in `config/claude/CLAUDE.md`,
  not enforced. Enforcing it takes a literal `denyWrite` entry per repo
  (Linux sandbox paths take no wildcard but a trailing `/**`); revisit with
  the harness choice below.
- `<leader>Cg` (`config/nvim/lua/qf_agent_changes.lua`, key in
  `nvim-bqf.lua`): moving the cursor onto a change in a buffer makes it the
  list's current entry, so `:cnext` goes on from there. The
  quickfix list of unstaged hunks and untracked files, each with the agent's
  note from `.agent-notes.md`, ignored in the new global
  `config/git/ignore`. The agent rewrites it every turn to describe what's
  still unstaged: a title (the commit subject), a summary with "This round",
  a `## path` heading per file with "- `7-18` — why" items, `· new` on this
  round's (listed first, marked `[new]`). The same text makes the chat
  summary. Rules for both in `config/claude/CLAUDE.md`. Try it in real
  rounds and adjust.
- Taken in; the sandbox writes in the project and not elsewhere in home
  (tested). Left: real rounds with `<leader>Cg`, to see how it works out.
- Stale note lines: after I reset or edit a hunk, the notes' line numbers
  still point at the old lines until the agent's next turn (seen: a 3-line
  comment reset, every later note 3 lines off). Fix in
  `qf_agent_changes.lua`: shift each note by the lines added or removed above
  it since the notes were written. That needs the diff at writing time to
  compare with, e.g. the agent puts each hunk's `@@` header (old-side range,
  which my edits don't move) next to the line range, and the plugin maps old
  ranges onto the live `git diff --unified=0`. Simpler fallback: snap each
  note to the nearest live hunk, and drop notes with no hunk left.
- Live reload: after the agent's turn I had to `:e` to see its changes in an
  open buffer. nvim's `autoread` is on by default but only acts when it
  checks, which it does on focus or shell commands, not on its own: a
  `:checktime` on `FocusGained`, `BufEnter`, `CursorHold` (and maybe a
  `vim.uv` fs watcher, or from `<leader>Cg` itself) would pick it up. Check
  whether tmux passes focus events (`focus-events on`).
- Inside the sandbox, `git status` lists the protected names that don't
  exist in the project (`.bashrc`, `.gitconfig`, `.vscode`,
  `.claude/settings.json`, …) as untracked: bwrap's mount points, visible
  only in the sandbox's view, not on disk. Only the agent's own git checks
  see them.
- Still on proposals: Claude Code's own settings (`config/claude/`), which it
  refuses to write anyway, so `claude.sh` stays for those.
- nixfiles caveat: its configs are linked live (`config/bashrc`,
  `config/nvim`), so an edit there runs outside the sandbox at my next shell
  or nvim start, before I've reviewed it.

Goal: one setup, done once, that serves Claude Code and Copilot CLI alike (see
"Copilot CLI in the container" in Next). The agent may write in the project,
as long as I can read every change and accept or reject it per line, per
hunk, per file or all at once. Its experiments still stay in `/tmp`.

Inspiration: smnatale/coderabbit.nvim. It runs the CodeRabbit CLI (`cr`) on
uncommitted changes, committed ones, or both (`review.type`, against
`review.base` or `review.base_commit`), and shows the findings as diagnostics
(critical/major/minor as ERROR/WARN/INFO), in a viewer grouped by file, and in
the quickfix list (`:CodeRabbitQuickfix`, or `quickfix.auto`); fixes come as
code actions, past reviews stay on disk (`:CodeRabbitHistory`). What appeals:
the quickfix list as the queue to work through, without leaving nvim.

Review through git, so it works the same for any agent: the agent edits the
working tree, I review the unstaged diff in nvim, and the index holds what I
accepted.

- Accept: `:Gitsigns stage_hunk` (a hunk, or the selected lines in visual
  mode), `git add <file>`, `git add --all`. Reject: `:Gitsigns reset_hunk`
  (same ranges), `git restore <file>`.
- Read: `:Gitsigns setqflist all` puts every hunk in the quickfix list to step
  through (see the quickfix item in Next). Side by side, working tree against
  index: nvim's own `nvim.difftool` (loaded in
  `config/nvim/lua/plugins/difftool.lua`) or diffview.nvim, where
  `:diffget`/`:diffput` also take single lines. Pick it together with the
  forge reviews item in Next, so one diff view serves both.
- Also to compare: codediff.nvim (VSCode-style diff with a list of changed
  files; check). The list of changed files may come from trouble.nvim
  instead (`:Gitsigns setqflist all` shown in its `qflist` mode, grouped per
  file; see the quickfix item in Next), which would leave codediff.nvim only
  its diff rendering.
- Jump between hunks: `]c`/`[c` (gitsigns' `nav_hunk`, nvim's own `]c` in a
  diff window) beside `<leader>ghn`/`<leader>ghp`
  (`config/nvim/lua/plugins/git.lua`). mini.diff overlaps gitsigns (signs,
  hunks, staging); only worth it for its overlay of the diff in the buffer,
  which gitsigns' `preview_hunk_inline` partly gives.
- Keep the agent's changes apart from mine: start from a clean tree (commit or
  stash first), or give the agent its own worktree. With writes in the repo
  allowed, the worktree's metadata in `.git` is no longer a problem.
- Enforce "staged means I accepted it" for every agent: `.git` read-only
  (per-repo sandbox entry for Claude; Copilot: check), or a harness that
  does it once for all repos.
- Or as git conflicts: the agent writes conflict markers, I pick a side with
  git-conflict.nvim (see its item in Next).
- The other way round, the agent reviewing my changes: coderabbit.nvim with
  Claude or Copilot in place of `cr`. `claude -p` (or `/code-review`), or
  `copilot -p`, on uncommitted changes or the branch against `main`, printing
  `file:line: message` lines that `:cexpr`/`:cfile` load into quickfix, or
  `vim.diagnostic.set` under its own namespace. Check whether coderabbit.nvim
  can take another CLI (`cli.binary`, `cli.extra_args`; it parses `cr`'s
  output, so likely not), else a small plugin of our own.
- Pointing the agent at code: `<leader>yr` copies `path/from/root:42`, or
  `:42-58` for a visual range (`config/nvim/lua/copy_reference.lua`, git
  root else the cwd; the root the status line in "nvim wishes" in Next can
  reuse). Maybe: the selection as a fenced code block with the language from
  `filetype` (```` ```cpp ````; a small map where names differ, e.g. `sh` →
  `bash`), the reference above it, on another `<leader>y` key.

Instead of or on top of that, approval per edit as it happens, from nvim:

- claudecode.nvim (coder) speaks Claude Code's IDE protocol, the one VSCode
  uses: each edit opens as a diff to accept or reject. Claude only.
- ACP (Agent Client Protocol): Copilot CLI has an ACP server (GitHub docs:
  `copilot-cli-reference/acp-server`), Claude Code works through an adapter
  (`claude-code-acp`; check), and nvim clients such as codecompanion.nvim
  drive either. One front-end for both; check which clients show edits as
  diffs to accept.

One harness for both, e.g. Pi (earendil-works/pi, was badlogic/pi-mono): a
minimal agent CLI you extend yourself (extensions, skills, prompt templates;
an RPC mode over JSONL for editors, and a TypeScript SDK). It takes a Copilot
token (`COPILOT_GITHUB_TOKEN`) and Anthropic credentials (`ANTHROPIC_API_KEY`
or `ANTHROPIC_OAUTH_TOKEN`); check whether my Claude subscription works there
and is allowed under its terms. Out of the box it has no permission system or
sandbox and runs with my rights. Community extensions add both
(`pi install npm:<name>`):

- Permissions: `@gotgenes/pi-permission-system` (allow/ask/deny per tool and
  path, e.g. deny `~/.ssh/*` and paths outside the project),
  `pi-permission-modes` (allow/ask/deny, bash commands parsed with
  tree-sitter), `pi-simple-permissions` (default/auto/yolo modes).
- Sandbox for bash: `@erichll/pi-sandbox`, `@nqbao/pi-sandbox`, `pi-sandbox`
  (chrisarderne), `@sysid/pi-sandbox`. The last two build on pi-mono's own
  example sandbox extension, on forks of `@anthropic-ai/sandbox-runtime`, the
  library behind Claude Code's sandbox (check). On Linux: bubblewrap, socat,
  ripgrep. Settings: writable paths, denied paths within them, network.
- Stand-in for auto mode: `@erichll/pi-auto-review`, a model that decides the
  `ask` cases and falls back to me on error or timeout.
- A write-up that combines the three: "A Pi setup with permission, sandbox,
  and auto-review" (ptgamr.substack.com).

Limits: extensions run inside Pi's process with my rights, so they're policy,
not a boundary. The sandbox covers bash only; Pi's read/write/edit tools run
in Node and obey only the permission rules, and other extensions' tools stay
unsandboxed. Each is third-party code to review before installing. For a
boundary, Pi's docs (pi.dev, "Run Pi in an isolated environment") list all of
Pi in a container (plain Docker; we have `bin/nix-devcontainer.sh`), Docker
Sandboxes (keeps the provider credential on the host), NVIDIA OpenShell, or
the Gondolin extension (a QEMU micro-VM for the built-in tools only; passes
the host environment in, so no credential boundary). Likely shape: Pi in the
container, plus a permission extension. We'd still lose Claude Code's plugins
(LSP) and skills, and auto mode becomes a third-party stand-in. Which
instruction files it reads: check.

Or keep both harnesses and share their config from nixfiles:

- Instructions: one `AGENTS.md` per project, which Copilot CLI reads; Claude
  Code reads `CLAUDE.md`, which can be just `@AGENTS.md`. Global:
  `config/claude/CLAUDE.md` and Copilot's user-level file (check where; it
  keeps its config in `~/.copilot`, moved by `COPILOT_HOME`).
- Skills: both support them; check whether one folder of `SKILL.md`s works
  for both, linked into `~/.claude/skills` and Copilot's.
- MCP servers: Claude's config and Copilot's `~/.copilot/mcp-config.json`,
  generated from one list in nix.
- Hooks and permissions differ (Copilot: `--allow-tool`, `--deny-tool`,
  `/sandbox enable`); keep them per harness, short.
- Language servers: see the Inbox item.

Run the agents in containers, one shape for both, built on
`bin/nix-devcontainer.sh`: the agent gets the project's toolchain (build,
tests, clangd) and nothing of the host it doesn't need. Today Claude runs on
the host, each command in bwrap (`check_bwrap_sandbox` in
`home/profiles/personal/preflight.sh`); the `container` profile has no agents
(no `modules/claude.nix`).

What the devcontainer opens up to an agent now, to close first:

- `~/nixfiles` is bind-mounted read-write: an agent could edit `config/bashrc`
  or a `bin/` script and so run code on the host at my next shell. Mount it
  read-only for the agent (check that `install.sh` needs no writes there).
- `/nix` and `/etc/nix` are read-write, with the nix daemon socket: the agent
  can build and add to the host's store. No escape by itself; check whether
  the agent needs more than read access.
- The network is open. Needs an allowlist, see below.

What a work devcontainer.json adds (as in
`dev-container-tests/.devcontainer/devcontainer.json`, its `runArgs`):

- `--network=host`: no firewall of its own is possible, and the host's
  localhost services are in reach. Claude's sandbox proxy (`strictAllowlist`)
  is then the only egress control.
- Credentials: `~/.ssh`, `~/.netrc` (also as `/root/.netrc`), `~/.jfrog`
  (read-write) and `/etc/apt/auth.conf.d/artifactory.conf`. The `~` ones are
  in `permissions.deny` of `config/claude/settings.json` already, and the
  container's home matches; `/root/.netrc` and the apt one are not.
- X11: `/tmp/.X11-unix` and `DISPLAY`. Any X client can read keys from and
  type into other windows on the host's X server; deny the socket in the
  sandbox (`denyRead`).
- `seccomp=unconfined` helps bwrap make its namespaces there.

Where the agent runs:

- In the devcontainer itself, beside my shell. The container keeps the agent
  off the host, but not away from what my shell has in there (the read-write
  nixfiles, `.git`, the history volume, any tokens), so Claude's bwrap stays
  the boundary between us. Deny `.git` through bwrap's `denyWrite`, not a
  read-only mount, and my shell can still stage. Claude only: Copilot has no
  per-command sandbox like it (check its `/sandbox enable`). bwrap inside
  rootless podman needs nested user namespaces (check with
  `bwrap --unshare-user --ro-bind / / true`; `failIfUnavailable` makes it fail
  loudly; `sandbox.enableWeakerNestedSandbox` is the weaker fallback, check).
  The host's AppArmor fix in `lib/host.sh` (`bwrap_fix_ok`) covers bwrap by
  path; check whether it reaches into the container, where the store path is
  the same.
- Container in a container: podman inside the devcontainer starts the agent's.
  Rootless podman-in-podman needs `/dev/fuse`, subuid ranges in the image and
  a loosened seccomp/SELinux profile on the outer container (check Red Hat's
  "How to use Podman inside of a container"). That weakens the box my own
  shell runs in, and the inner container needs the project toolchain again:
  the same image twice.
- Sibling container (likely): `nix-devcontainer.sh` starts, on request (flag
  to name), a second container from the same image beside mine. Same
  workspace, with `.git` bound read-only over it (or the agent's own
  worktree); `/home/ubuntu/nixfiles` read-only; its own volumes for
  `~/.claude` and `~/.copilot`, like the bash history volume; only the
  credentials of its context (see below); the egress allowlist. Mine keeps a
  writable `.git` to stage. No nesting, no extra privileges. Claude's bwrap
  is optional there, a second layer: it keeps the agent's commands from
  rewriting its own settings and hooks (moot if it skips prompts anyway), and
  filters the network per command. Start it with `podman run` on the image
  `devcontainer up` built, with our own arguments: a second `devcontainer up`
  would repeat the project's `runArgs` (host network, credentials, X11; see
  above).
- Projects without `.devcontainer/` (nixfiles, personal ones): a default
  image (plain Ubuntu plus the `container` profile), so one script serves all.
- Install: `modules/claude.nix` and Copilot CLI (nixpkgs attr: check) in the
  `container` profile, or an `agents` module that profiles import. Images
  need nothing: neither ours nor work's has bwrap, but nixpkgs' `claude-code`
  brings bubblewrap and socat itself (its wrapper puts socat on `PATH`, and it
  runs bwrap from the store), all through the `/nix` mount.
- Egress: Anthropic's reference devcontainer (anthropics/claude-code,
  `.devcontainer/init-firewall.sh`: iptables and ipset, deny by default, needs
  `NET_ADMIN`) is the model. Rootless alternative: no network for the
  agent's container except a proxy that passes only listed hosts (check what
  podman offers). Hosts: the model API, GitHub, the nix cache, and for work
  Artifactory.
- Inside, the agent may skip its own prompts (`--dangerously-skip-permissions`,
  Copilot `--allow-all-tools`), as the container is the boundary. Decide; auto
  mode may be the middle ground.
- Reaching nvim from the agent's container: claudecode.nvim talks over a
  WebSocket on localhost, ACP over stdio. Check whether that crosses containers
  (shared network namespace, `--network container:<mine>`), or whether review
  through the shared working tree is enough.

Which model may see what. Company code and secrets go only to a model under
the company's contract: Copilot through the work org's Business/Enterprise
seat, Claude only if work has a contract (Team/Enterprise, an API org,
Bedrock/Vertex; ask at work what's approved). My own Claude subscription and
personal Copilot only for personal projects. Fix it per container, not per
prompt, so picking wrong can't happen:

- Context from the workspace: under `~/git/lely` (the path `gitconfig`'s
  `includeIf` already uses), or a marker in the project → work; else
  personal. An override only towards work.
- Credentials: a container gets only its context's tokens, never both, from
  sops through `nixfiles-secrets` (see "Copilot CLI in the container" in
  Next). Work: a token of the work GitHub account in `COPILOT_GITHUB_TOKEN`;
  for Claude the company's key or Bedrock variables (`CLAUDE_CODE_USE_BEDROCK`).
  Personal: `CLAUDE_CODE_OAUTH_TOKEN` from `claude setup-token`, and my own
  GitHub token.
- Egress: the work allowlist names only the work endpoints, so a wrong setting
  fails to connect instead of sending code out.
- Models: the work org's Copilot policy decides which models the work account
  gets (Claude models through Copilot too). Claude Code: managed settings
  (`/etc/claude-code/managed-settings.json`, in the image or bind-mounted) pin
  `model` and may limit the picker (`availableModels`; check). Copilot CLI:
  `--model`, or `model` in its config.
- Show it: `config/claude/statusline.sh` and the bash prompt show WORK or
  PERSONAL inside the container.
- Not: proxies that put Copilot's models behind Claude Code (copilot-api and
  the like); likely against GitHub's terms.
- The host: Claude runs on the work laptop now too (`lely` imports
  `personal`), kept off work code by `Read(~/git/lely/**)` in
  `permissions.deny` of `config/claude/settings.json`. Keep that, or move all
  agent use into containers and drop Claude from the host.

Then:

- The same write rules for Copilot as for Claude (see the easy path above).
- Rewrite the rules in `config/claude/CLAUDE.md` (or the shared `AGENTS.md`)
  to match what we pick.

## Next

### 2026-11-14 · nvim wishes

From my notes; each a small change in `config/nvim`. Keys to the layers in
`README.md` and the groups in `which-key.lua`.

Looks:

- Highlight the enclosing brackets with the cursor between them. nvim's own
  matchparen only does so with the cursor on a bracket. Without a plugin: a
  `CursorMoved` autocmd (debounced) that finds the enclosing pair
  (`searchpairpos`, skipping strings and comments, or the treesitter node)
  and marks both ends with extmarks in a namespace of its own. Plugin
  alternative: vim-matchup (`matchup_matchparen_hi_surround_always`; check).
- One global status line: `globalstatus = true` in
  `config/nvim/lua/plugins/lualine.lua` (`laststatus=3`). Check the dap-ui
  and neotest windows: their `panels` extension there then shows only while
  one has focus, and they lose their own titles (a `winbar` per panel could
  take that over). File name as a path from the project root
  (`vim.fs.root(0, ".git")`, else the cwd): lualine's `filename` with
  `path = 1` is relative to the cwd only, so a small function of our own.
  The path is also what the copy-a-reference keys in Now use. Look into how
  to show which window is current once windows have no status line of their
  own: a `winbar` with the file name, dimmed in the others (`WinBarNC`);
  inactive windows dimmed (`NormalNC`); a coloured `WinSeparator` for the
  active window (through its `winhighlight`; check); the cursorline wish
  below helps too. Ties in with "Merge nvim's statusline into the tmux
  status" in Later.
- Current line only in the active window: `cursorline` is on already
  (`config/nvim/lua/options/init.lua`), but it's window-local, so every
  window shows one. `WinEnter`/`WinLeave` autocmds turn it on and off, no
  plugin. Inactive windows draw no cursor, so what looks like a second
  cursor is likely their cursorline (check).

Editing:

- Persistent undo: `undofile = true`, files in `~/.local/state/nvim/undo`.
  Check whether that survives a container rebuild (volume?), and prune old
  files now and then (nvim never does).
- `]]`/`[[` to the next/previous occurrence of the word under the cursor, and
  all occurrences highlighted. Now: LSP `document_highlight` on `CursorHold`
  marks references already (`LspAttach` in
  `config/nvim/lua/plugins/lsp.lua`); `*`/`#` jump by text. `]]`/`[[` are
  nvim's section motions (`{` in column 1), rarely useful. Options: keys of
  our own over the `textDocument/documentHighlight` positions, falling back
  to `*`/`#` without LSP; or snacks.nvim's `words` module, which does this
  on `]]`/`[[` (see "nvim plugins to evaluate" in Later).
- Format only changed lines: `vim.lsp.buf.format({ range = … })` per hunk
  from `require("gitsigns").get_hunks()`, in the `BufWritePre` autocmd in
  `lsp.lua`. Needs range formatting from the formatter: clang-format and
  stylua through none-ls (check); black has `--line-ranges`; nixfmt and
  shfmt have none (whole file, or skip). conform.nvim has a recipe for it
  (check). Maybe per repo: whole file in mine, changed lines at work.
- Toggle format on save: `vim.g.format_on_save` (session) and
  `vim.b.format_on_save` (buffer, from `.editorconfig`) exist in `lsp.lua`;
  add a `:FormatToggle` command (buffer or session) and a key, and show the
  state in the status line. rustaceanvim's own `BufWritePre` in `lsp.lua`
  formats `*.rs` regardless; route it through the same check.

Windows and tabs:

- `s` as the prefix for windows (move, split, close, resize, maximize), like
  `<C-w>`. `s` is free: nvim's substitute (`cl` does the same), flash's char
  mode is off and flash sits on `<CR>`, nvim-surround uses `ys`/`ds`/`cs`
  and visual `S`. Now: `<C-h/j/k/l>` to move (stays, Ctrl layer), the
  `<leader>S` Split group (`config/nvim/lua/keymaps.lua`), `<C-arrows>` to
  resize, `<leader>vsf` to maximize (vim-maximizer). Decide what moves.
- Tabs as sets of windows (code, a review, debugging). Tabline only with two
  or more tabs (`showtabline = 1`, the default), a tab marked when one of
  its windows shows a modified buffer (`[+]` or a nerdfont glyph): our own
  `tabline` function, or lualine's `tabline` with its `tabs` component.
  Names: set by hand (`vim.t.name`, a rename key), else the first window's
  buffer. Keys for new, close, move, next/previous (`H`/`L` cycle buffers
  now; `gt`/`gT`, or under the `s` prefix). Check that resession keeps tabs
  and their names.

Files and git:

- File explorer: mini.files now (`<leader>ve`, preview on, in `mini.lua`;
  syncs with `=`). oil.nvim has previews now too: compare, as a float
  (`oil.open_float`), syncing on `:w`. Or keep mini.files, if it can sync on
  `:w` (check its docs; else a `BufWriteCmd` that calls
  `MiniFiles.synchronize()`).
- lazygit's `e`: `os.editPreset: "nvim"` in `config/lazygit/config.yml`
  starts a new nvim, also from `<leader>gg` (lazygit.nvim's float).
  lazygit's `nvim-remote` preset does both: inside nvim (`$NVIM` is set in
  its terminals) it opens the file in that nvim, on its own it starts nvim
  (check how it closes lazygit.nvim's float). First hunk on open: a custom
  `edit` command with `+'Gitsigns nav_hunk first'` (check that gitsigns has
  attached by then; it does so async).

### 2026-10-04 · setlocale warnings in the work container

bash warns it cannot set `en_US.UTF-8` (LC_CTYPE, LC_COLLATE). Our config sets
no `LANG`; the image's glibc has no such locale, and `LOCALE_ARCHIVE_2_27` only
helps nix programs. Find where `LANG` comes from (image `ENV`, devcontainer.json
`containerEnv`/`remoteEnv`), then e.g. `--remote-env LANG=C.UTF-8` in
`bin/nix-devcontainer.sh`.

### 2026-11-05 · Copilot CLI in the container

Needed for work; Claude Code covers it for now. Open question: deliver the token
through `nixfiles-secrets` (sops) so a container rebuild costs nothing. Likely
shape: a token on the host from sops, passed in by `bin/nix-devcontainer.sh` as
an environment variable or bind-mounted file, like the per-workspace bash
history mount there. Which container gets which token, and the agent's own
container: see the containers part of "How I take in changes from Claude and
Copilot" in Now.

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

### 2026-11-03 · GitLab/GitHub reviews in nvim

Review merge and pull requests in nvim: read the diff, comment on lines, reply
to threads, approve. Ties in with "How I take in changes from Claude and
Copilot" in Now: ideally the same diff view and quickfix flow for an agent's
changes and a colleague's request. Candidates: octo.nvim (GitHub only; PRs,
review threads, through the `gh` CLI) and harrisoncramer/gitlab.nvim (GitLab
only; MR comments and approvals, on diffview.nvim, with a small Go server it
builds; check). Neither covers both; just reading a diff works for either with the
branch fetched and a local diff view. Check first which forge work uses, and
whether it's a self-hosted GitLab. Tokens: same question as "Copilot CLI in
the container" (sops through `nixfiles-secrets`), plus `gh`/`glab auth`.

### 2026-11-13 · Lists of results: quickfix, quicker.nvim or trouble.nvim

Where the result is a list to work through (references, diagnostics, grep
hits), show it as a list that stays open, and keep fzf-lua for picking one
thing (files, buffers, help, keymaps, commands). Now in
`config/nvim/lua/plugins/fzf.lua`: `<leader>lf` (`FzfLua lsp_finder`,
references and the like), `<leader>ld`/`<leader>lD` (diagnostics),
`<leader>fs`/`<leader>fc` (grep). Already on quickfix: `<leader>Cd`
(diagnostics, in `nvim-bqf.lua`), `<leader>vt` (todo-comments), and nvim's own
defaults `grr` (references), `gri` (implementations) and `gO` (document
symbols, location list). Ways in: plain `vim.lsp.buf.references()` and
friends (their `on_list` option sends results anywhere), `:grep` with ripgrep
as `grepprg`, or keep fzf-lua and send its results on (it has actions to send
the selection to quickfix or to trouble; check the keys).

Where the list lives, to compare:

- Plain quickfix with nvim-bqf, as now (`nvim-bqf.lua`: preview window, fzf
  filter). `:colder`/`:cnewer` bring back earlier lists, `:packadd cfilter`
  gives `:Cfilter` to narrow one. The quickfix list is also what `:cdo`,
  `:cfile` and `:Gitsigns setqflist` use, so the agent review flow in Now
  runs on it whatever we pick here.
- quicker.nvim (stevearc): a better quickfix buffer, not a new list. Edit the
  lines and `:w` writes them back to the files (rename or fix across all
  hits), expand and collapse context lines around an entry (keys of our own,
  its README uses `>`/`<`), aligned columns with highlighted code. Check
  whether it works beside nvim-bqf (both take over the qf window) or which to
  keep.
- trouble.nvim (folke, v3): its own list window beside quickfix, grouped per
  file as a tree, with preview, follow-cursor and refresh as you edit.
  Modes quickfix lacks: `lsp` (definitions, references, implementations and
  type definitions in one, like `lsp_finder`), `lsp_incoming_calls` and
  `lsp_outgoing_calls` (call hierarchy as a tree), `symbols` (document
  outline, in place of `gO`), `diagnostics` filtered per buffer or severity.
  It can show the quickfix and location lists too (`qflist`, `loclist`).
  Catppuccin's `lsp_trouble = true` is already on in `catppuccin.lua`.
  Downside: a second list with its own keys; quickfix stays for `:cdo` and
  the like.
- Likely shape: quickfix (with quicker or bqf) as the queue to work through
  and edit; trouble for exploring LSP results (references, call hierarchy,
  symbols). Decide per list which one it goes to.
- More to look at: glance.nvim (references and definitions in a VSCode-like
  peek float, editable in place; check it's maintained), and outline plugins
  (aerial.nvim, outline.nvim) if trouble's `symbols` falls short.

Keys to the layers in `README.md` and the groups in `which-key.lua`
(`<leader>C` is Quickfix, `<leader>l` LSP); trouble's keys go under one of
those, not a group of its own.

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

### 2026-11-11 · Mermaid diagrams inline in nvim

For now live-preview.nvim (`<leader>vp`, in
`config/nvim/lua/plugins/markdown.lua`) shows Markdown with its Mermaid
diagrams in the browser, on the host only. In a container it can't open a
browser, and its server listens on the container's `127.0.0.1` (reachable from
the host only with `--network=host`, as work containers have; else
`address = "0.0.0.0"` and a published port). Find the nicest way to see them
in nvim itself, which also covers the container:

- Images in the buffer: snacks.nvim's `image` module renders ```` ```mermaid ````
  blocks where they sit, through `mmdc` (mermaid-cli); diagram.nvim (3rd, on
  image.nvim) does Mermaid, PlantUML, D2 and gnuplot. Both need the Kitty
  graphics protocol, which Alacritty lacks: kitty, Ghostty or WezTerm instead,
  and `allow-passthrough on` in `config/tmux/tmux.conf`. image.nvim's
  ueberzugpp backend works in any terminal, but on Wayland only for some
  compositors, and it misplaces images in tmux.
- Text in the buffer: the `mermaid-ascii` CLI draws flowcharts and sequence
  diagrams as ASCII; no plugin known, a keymap could pipe the block under the
  cursor into a float.
- Check whether Alacritty has gained a graphics protocol by then.

### 2026-11-14 · nvim plugins to evaluate

- snacks.nvim (folke): a bundle of small modules (picker, image, notifier,
  dashboard, words, …), each enabled on its own. Its `image` module is a
  candidate for "Mermaid diagrams inline in nvim" above, its `words` for the
  `]]`/`[[` wish in "nvim wishes" in Next; its picker overlaps fzf-lua.
- nvim-hlslens: match index next to search results.
- blink-ripgrep.nvim: blink.cmp source with words from the whole project.
- treesj: split/join on treesitter nodes; overlaps mini.splitjoin.
- tiny-inline-diagnostic.nvim: nicer inline diagnostics.
- nvim-chainsaw: insert and remove log statements.

### 2026-11-03 · nvim's own catppuccin instead of the plugin

nvim 0.12 ships `colors/catppuccin.vim` in `$VIMRUNTIME` (Latte for
`background=light`, Mocha for dark), so `:colorscheme catppuccin` works
without catppuccin/nvim (`config/nvim/lua/plugins/catppuccin.lua`). Do we
still need the plugin? The bundled one is a port of Vim's (Colortemplate,
vim/colorschemes) and covers the core groups only: syntax, UI, diff, `Pmenu*`,
quickfix, markdown. It has no treesitter `@` groups, no `Diagnostic*` or LSP
groups, none of the integrations we turn on (gitsigns, dap, noice, which-key,
flash, navic, indent-blankline, …), no other flavours and no options (our
italic virtual text, underlined diagnostics); those fall back to nvim's default
links. Also on the plugin: `lualine.lua` reads `catppuccin.palettes.mocha`,
and `dap.lua` copies colours from its dap integration. With both installed the
plugin wins (`g:colors_name` is `catppuccin-mocha`). To check: disable the
plugin and compare C++, Lua and Nix files with diagnostics, a diff and the dap
UI; keep the plugin if the gaps show. One plugin fewer to package in "nvim
plugins through nix" in Next.

### 2026-10-04 · Code-aware spell checker in nvim

Baseline without installs: `:set spell`, which with treesitter only checks
comments and strings. Candidates, all in nixpkgs with an nvim-lspconfig config:
codebook (tree-sitter based, splits identifiers like `camelCase`), typos-lsp
(list of known misspellings, few false positives), harper (spelling and grammar
in comments and Markdown). ltex-ls-plus (LanguageTool) is heavier, on a JRE.

### 2026-10-03 · TUIs to look into

- TUIOS: window manager inside the terminal.
- superfile: file manager; compare with yazi, which is in use now.

### 2026-11-14 · Merge nvim's statusline into the tmux status

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
  status format. Splits lose their own status line, as with the global
  status line in "nvim wishes" in Next (do that first); a `winbar` with the
  file name covers that. Check what
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
