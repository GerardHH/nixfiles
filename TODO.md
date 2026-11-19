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

- 2026-11-15 · Give Claude Code and Copilot CLI access to language servers
  (clangd, nixd, …), as Copilot has through VSCode: definitions, references and
  diagnostics instead of grep. Claude Code already has an `LSP` tool (fed by
  plugins); check what it needs to use our servers, and whether Copilot CLI has
  the same or can get it through MCP. Ties in with "Copilot CLI in the
  container" in Now. Its lua_ls lacks nvim's settings: see "Agents run
  formatters and analyzers" in Next.

- 2026-11-14 · Sandbox read denials with a leading `**` don't work on Linux:
  `Read(//**/.env)` and `Read(//**/secrets.d/**)` in
  `config/claude/settings.json` stop the Read tool only; a sandboxed `cat` of
  a `.env` succeeds (tested). Linux takes a wildcard only after the first
  directory name, so e.g. `~/**/.env`, `/run/**/secrets.d`; check which
  paths matter.

- 2026-11-17 · lazygit left open idles at ~50% of a core (seen: 32 min, its
  `git` and `delta` children respawning), enough to keep the laptop at 95 °C
  and throttling; closing it cooled things down, so for now I keep it closed.
  Suspects: the 10 s auto-refresh (`refresher.refreshInterval`) redrawing the
  main view through delta (`diffRenderers` in `config/lazygit/config.yml`),
  worst with a big diff or the `git list-tree` graph selected; check which
  panel, then raise the interval or limit the graph. The laptop also runs in
  `performance` platform profile, which makes light loads run hot.

## Now

### 2026-11-17 · Dev-containers as the sandbox

Decided (2026-11-17): the dev-container is the agents' boundary, and nvim runs
in it too, so the agent and I work with the same tools (toolchain, clangd,
formatters, linters). Claude and Copilot move off the host into it, built on
`bin/nix-devcontainer.sh`. Top priority, with the Copilot item below. Today
Claude runs on the host, each command in bwrap (`check_bwrap_sandbox` in
`home/profiles/personal/preflight.sh`); the `container` profile has no agents
(no `modules/claude.nix`).

Name: devbox (from a chat with Claude), or nix-devbox if nix ends up building
the box itself (see "What goes in" below); `bin/nix-devcontainer.sh` gets
renamed with it. Jetify's Devbox (jetify-com/devbox) is a nix-based CLI called
`devbox`, so the bare name clashes on `PATH` and in searches; nix-devbox doesn't
(check it isn't taken too).

Front end (decided 2026-11-17): agentic.nvim in the devbox, driving Claude Code
(through `claude-agent-acp`) and Copilot CLI (`copilot --acp`) over ACP, each
with its own login, so every subscription stays in the harness it's allowed in.
What it does with permissions and why it won over codecompanion.nvim: the ACP
bullet in "How I take in changes" in Next. The devbox comes in variants, one
personal and one per work context (see "Which model may see what" below).

Two rules follow from it:

- No secrets in the container: whatever is in there, the agent can read and
  send out. One exception to settle: the model's own token (see the Copilot
  item below).
- Git's remote work stays on the host, as with VSCode now: no keys in the
  container, so no push, fetch or signed commits there. Local git (status,
  diff, gitsigns' hunks and staging) needs no keys and works as long as `.git`
  is mounted.

What `nix-devcontainer.sh` opens up now, to close first:

- `~/nixfiles` is bind-mounted read-write: an agent could edit `config/bashrc`
  or a `bin/` script and so run code on the host at my next shell. Mount it
  read-only (check that `install.sh` needs no writes there); I edit nixfiles
  on the host. nvim's config in the container comes from that mount too.
- `/nix` and `/etc/nix` are read-write, with the nix daemon socket: the agent
  can build and add to the host's store. No escape by itself; see "What goes
  in" below.
- The network is open. Needs an allowlist, see below.

What goes in. Now the script mounts all of `/nix` and `/etc/nix` read-write,
then runs `install.sh` inside, a full `home-manager switch` of the `container`
profile on every start (see "`install.sh`: skip the switch" in Later). Options:

- As now: whole `/nix` with the daemon, `install.sh` inside. The agent can
  build anything and run `nix develop`, and adds to the host's store.
- Build on the host, mount the result: the host builds the profile's
  `activationPackage`; the box gets `/nix/store` read-only (whole, or only the
  profile's closure from `nix-store --query --requisites`) and no daemon
  socket, then only activates, or gets the generation's home files mounted
  directly. No `install.sh` and no build inside, but also no `nix build` or
  `nix develop` for the agent; decide whether projects need them. Check that
  the store holds nothing secret (sops-nix keeps only encrypted files there).
- Config files: the out-of-store links (`link "config/…"`) keep working as
  long as nixfiles is mounted, read-only, at the same path.
- Nix builds the image (`dockerTools.buildLayeredImage`, nix2container) with
  the profile inside: the nix-devbox case. Fits the default image for projects
  without `.devcontainer/`; work projects bring their own image, so there the
  profile still comes in through a mount.

A nix box, for the agent to help with nixfiles itself: the daemon socket, nixd,
nixfmt, and network to the nix cache and GitHub (flake inputs), so it can run
`nix flake check` and `home-manager build`, but never `switch`; I activate on
the host. It must not edit the live checkout: `~/nixfiles` is linked into my
shell and nvim, so an edit there runs on the host before I've read it. Give it a
worktree or clone of nixfiles instead (see the worktree idea in "How I take in
changes" in Next), so changes reach the host only through git.

Nix alternatives (a quick look, 2026-11-17). Two kinds, neither replaces the box
where a project brings its own container:

- Per-project environments: devenv (Cachix; generates a `devcontainer.json`
  for Codespaces), Flox (manifest on top of nix, `flox containerize` makes an
  image), Jetify's Devbox, or a plain flake devShell with direnv. They say
  which tools a project gets, not what the agent may reach; Flox's own agent
  docs keep the devcontainer as the boundary and Flox inside it. For a work
  project they would sit inside its container, which our profile through
  `/nix` already does.
- Nix-native jails around the agent, no container: jail.nix (sourcehut
  `~alexdavid/jail.nix`, a nix wrapper for bwrap; mounts only the cwd),
  jailed-agents (codecentric, built on jail.nix; installs in a devShell or
  devenv), aibox (ruifm/aibox: bwrap with the project's devShell through
  direnv, and state rules for Claude, Codex and Copilot CLI), ai-jail (Rust,
  bwrap; a fresh tmpfs home, agent state only on request). Light and
  declarative, but for a project whose tools live in its container image the
  agent then lacks them, unless the jail runs inside that container (nested
  bwrap, the question under Shape below).
- So: the box stays the shape for work. For nixfiles and personal projects
  without `.devcontainer/`, a jail plus the project's devShell could replace
  the default image; one shape for all keeps one set of rules, though. Worth
  reading either way: how aibox and jail.nix handle agent state and mounts.

Projects I don't fully control decide what gets mounted through their
`devcontainer.json`. The work one (as in
`dev-container-tests/.devcontainer/devcontainer.json`, its `runArgs`) brings:

- Credentials: `~/.ssh`, `~/.netrc` (also as `/root/.netrc`), `~/.jfrog`
  (read-write) and `/etc/apt/auth.conf.d/artifactory.conf`.
- `--network=host`: no firewall of its own is possible, and the host's
  localhost services are in reach.
- X11: `/tmp/.X11-unix` and `DISPLAY`. Any X client can read keys from and
  type into other windows on the host's X server.
- `seccomp=unconfined`.

Override that, so no project can add secrets: build the image as the project
defines it (the build may need the Artifactory credentials, e.g. for apt; they
stay in the build, on the host), then run it with our own arguments only. Either
`podman run` on the built image, or `devcontainer up --override-config` with a
config of ours (check whether it replaces `runArgs` and `mounts` or merges
them). Keep what the project needs to work (`containerEnv`, `postCreateCommand`;
check whether the work one needs the host network to reach anything).

Shape:

- One container for me and the agent: nvim, my shell and the agent side by
  side. With no secrets inside, little is left between us to guard, and
  claudecode.nvim's WebSocket on localhost or ACP's stdio reach nvim
  directly. Claude's bwrap is an optional second layer: it keeps the agent's
  commands from rewriting its own settings and hooks, and filters the network
  per command. Inside rootless podman it needs nested user namespaces (check
  with `bwrap --unshare-user --ro-bind / / true`; `failIfUnavailable` makes it
  fail loudly; `sandbox.enableWeakerNestedSandbox` is the weaker fallback,
  check). The host's AppArmor fix in `lib/host.sh` (`bwrap_fix_ok`) covers
  bwrap by path; check whether it reaches into the container, where the store
  path is the same. Copilot has no per-command sandbox like it (check its
  `/sandbox enable`).
- Projects without `.devcontainer/` (nixfiles, personal ones): a default
  image (plain Ubuntu plus the `container` profile), so one script serves all.
- nvim on the host stays, without the agent plugins: there it has the
  secrets (git credentials, sops), the box has the agents. One nvim config
  for both, the agent plugins only where the profile says so (e.g. a flag
  the profile writes for nvim, as `nix_languages.lua` does for languages).
- Install: `modules/claude.nix`, Copilot CLI (`github-copilot-cli`, 1.0.61 in
  our nixpkgs) and, for agentic.nvim, `claude-agent-acp` (0.36.1) in the
  `container` profile, or an `agents` module that profiles import. Images
  need nothing: neither ours nor work's has bwrap, but nixpkgs' `claude-code`
  brings bubblewrap and socat itself (its wrapper puts socat on `PATH`, and it
  runs bwrap from the store), all through the `/nix` mount.
- Agent state: volumes for `~/.claude` and `~/.copilot`, like the bash history
  volume, so a rebuild keeps settings and sessions.
- Egress: Anthropic's reference devcontainer (anthropics/claude-code,
  `.devcontainer/init-firewall.sh`: iptables and ipset, deny by default, needs
  `NET_ADMIN`) is the model. Rootless alternative: no network for the
  container except a proxy that passes only listed hosts (check what podman
  offers). Hosts: the model API, GitHub, the nix cache, and for work
  Artifactory; what the agent may look up comes on top, see below.
- Inside, the agent may skip its own prompts (`--dangerously-skip-permissions`,
  Copilot `--allow-all-tools`), as the container is the boundary. Decide; auto
  mode may be the middle ground.
- nvim in the container day to day makes three Later items more pressing:
  "Pasting host → container only works with Ctrl+Shift+V", "Nested tmux in
  the container", and the browser preview in "Mermaid diagrams inline in
  nvim".
- Once this works, drop Claude from the host (it runs on the work laptop now,
  `lely` imports `personal`, kept off work code by `Read(~/git/lely/**)` in
  `permissions.deny` of `config/claude/settings.json`), and with it the
  sandbox read-denial item in Inbox.

Carry over the safety settings we have for Claude on the host
(`config/claude/settings.json`: permissions and sandbox; rules in
`config/claude/CLAUDE.md`):

- Reads and writes: covered by what's mounted. No secrets inside, the project
  read-write, `.git` and nixfiles read-only. The `permissions.deny` entries for
  `~/.ssh` and the like become moot in the box.
- What the agent may look up on the internet: still to set up. Layers: the
  box's egress allowlist; Claude's sandbox network allowlist per command;
  Claude's `WebFetch(domain:…)` permission rules; Copilot's own URL rules
  (check what it has). WebSearch runs on Anthropic's side, so the box's
  egress doesn't see it (check); decide whether to allow it. A start for the
  list: language and library docs, GitHub, package registries (nixpkgs,
  crates.io, PyPI), and for work the work forge. A narrow list limits both
  where injected instructions can come from and where code can go.
- Rules: those tied to the host (scratchpad in `/tmp/claude-1000`,
  `claude-diff`/`claude-take` for Claude's own settings) change in the box;
  review them then, together with Copilot's `AGENTS.md`.

Which model may see what. Company code and secrets go only to a model under
the company's contract: Copilot through the work org's Business/Enterprise
seat, Claude only if work has a contract (Team/Enterprise, an API org,
Bedrock/Vertex; ask at work what's approved). My own Claude subscription and
personal Copilot only for personal projects. Fix it per container, not per
prompt, so picking wrong can't happen:

- Variants: one personal devbox, and a work devbox per work context: lely
  now, more as projects come (another customer, a project under its own
  contract or toolchain). Each variant is a profile, in place of the one
  `container` profile now (on the host, `lely` imports `personal`): a shared
  devbox module (nvim, agentic.nvim, shell, the agent harnesses) plus a small
  module per variant with what differs: tools (check what the work setup
  needs, e.g. Artifactory's CLI), the agent and token, the egress allowlist,
  the managed settings (models), and the workspace paths it serves. Adding a
  variant should be one new module and one entry in a list, not edits across
  the scripts.
- Context from the workspace: each work variant names its paths (lely:
  `~/git/lely`, the path `gitconfig`'s `includeIf` already uses) or a marker
  in the project; anything unclaimed is personal. An override only towards
  work, never from one work variant to another. Check the resolved path, so a
  symlink can't hide a work folder; a work forge in the git remotes is a
  second sign.
- A box refuses other variants' workspaces: the script stops with an error
  before starting the personal box on work code, or one work variant's box on
  another's (their contracts and tokens may differ), so it never mounts the
  code.
- Model token: a container gets only its context's, never both, and nothing
  else (see the Copilot item below). Work: a token of the work GitHub account
  in `COPILOT_GITHUB_TOKEN`; for Claude the company's key or Bedrock variables
  (`CLAUDE_CODE_USE_BEDROCK`). Personal: `CLAUDE_CODE_OAUTH_TOKEN` from
  `claude setup-token`, and my own GitHub token.
- Egress: each work variant's allowlist names only its own endpoints, so a
  wrong setting fails to connect instead of sending code out.
- Models: the work org's Copilot policy decides which models the work account
  gets (Claude models through Copilot too). Claude Code: managed settings
  (`/etc/claude-code/managed-settings.json`, in the image or bind-mounted) pin
  `model` and may limit the picker (`availableModels`; check). Copilot CLI:
  `--model`, or `model` in its config.
- Show it: `config/claude/statusline.sh`, the bash prompt and agentic.nvim's
  window show the variant's name (PERSONAL, LELY, …) inside the container.

### 2026-11-17 · Copilot CLI in the container

What we build for agents only pays off at work once Copilot CLI runs there, as
work code goes to Copilot. It's installed in the dev-container with Claude (see
above). Its token is the one secret the container would hold, against the
no-secrets rule. Options:

- A narrow token: a fine-grained token of the work GitHub account with only
  the "Copilot Requests" permission (check that Copilot CLI takes one), in
  `COPILOT_GITHUB_TOKEN`. Leaked, it spends Copilot requests but reaches no
  code. On the host from sops through `nixfiles-secrets`, passed in by
  `bin/nix-devcontainer.sh` as an environment variable or bind-mounted file,
  like the per-workspace bash history mount there, so a rebuild costs nothing.
- No token inside: a proxy on the host adds it to requests on their way out,
  as Docker Sandboxes do with the provider credential. Check whether Copilot
  CLI can go through such a proxy without TLS interception.

The same choice for Claude's token.

## Next

### 2026-11-19 · An agent as first pass on colleagues' reviews

High priority, apart from the devbox work. For merge requests by others (and
their agents), not my own agent's changes: those keep the flow in "How I take in
changes" below. Requests written with agents come in bigger and looser, and
reviewing them takes me ever longer. Let an agent go over a request first, so I
start from a list instead of the raw diff.

- Start: the agent writes a Markdown file of findings, one per line as
  `path:line: why it flagged this`, which `:cfile` or trouble loads (see "Lists
  of results in trouble.nvim" below), and I work through it beside the diff
  (see "GitLab/GitHub reviews in nvim" below, where my comments go back to the
  forge). Claude Code's `/code-review` covers bugs (check its output format);
  work code goes to Copilot only (see "Which model may see what" in Now).
- Cheap first: what a machine can say without judgement. The request's
  intent in a few lines, changes unrelated to it, size, files touched that
  usually aren't, duplication of code that already exists, tests missing for
  new paths. Checks that a linter or CI can own instead move there.
- What matters most to me and is hardest to capture: readability, and
  whether the change fits the architecture. Ideas: write down what I look
  for as a review guide per project (`REVIEW.md`, or in `AGENTS.md`) with the
  architecture's layers and rules, maybe as ADRs; gather my own past review
  comments from the forge as examples of what I flag; ask the agent for
  questions ("why does X now reach into Y?") rather than verdicts. Not sure
  yet; try on a few real requests and compare with what I would have said.
- Also the process side: ask authors for smaller requests and a description
  of intent, so the agent and I both have something to check against.

### 2026-11-17 · Agents run formatters and analyzers

Claude ran stylua and rumdl on the agent-review specs, but no Lua analyzer;
lua-language-server's check then found 10 real warnings (fixed). Make linting
something the agent can't skip. Moved below the sandbox and Copilot
(2026-11-17); once the agents run in the dev-container, the tools come from its
toolchain and the hook runs there.

- Rule: the proposal in `/tmp/claude-1000/nixfiles/config/claude/CLAUDE.md`
  replaces the Markdown linter rule with one for every formatter and
  analyzer (`claude-diff`, `claude-take`). Later in the shared `AGENTS.md`,
  for Copilot too.
- Hook: a `PostToolUse` hook on Edit/Write in `config/claude/settings.json`
  that runs the file's formatter and analyzers and hands the warnings back
  to the agent, so it doesn't depend on the rule. Per language: stylua and
  `lua-language-server --check` (Lua), rumdl (Markdown), shellcheck and shfmt,
  nixfmt, clang-format and clang-tidy. Copilot CLI: check whether it has
  hooks.
- One command per project, e.g. `make lint` in agent-review and
  neotest-testmate, for the rule and the hook to find.
- lua-language-server's check outside nvim needs the settings nvim's `lua_ls`
  gets (`config/nvim/lua/plugins/lsp.lua`): LuaJIT, and as library
  `$VIMRUNTIME`, `${3rd}/luv`, `${3rd}/busted`, `${3rd}/luassert`. A
  `.luarc.json` per Lua project would carry them for the CLI, nvim and
  Claude Code alike (check how to name `$VIMRUNTIME` there; its store path
  changes with each nvim).
- Claude Code's own lua_ls (its diagnostics after an edit) runs without
  those settings, so it flags `vim` as undefined in every file and buries the
  real warnings. The `.luarc.json` may fix that; see also the language
  servers item in Inbox.

### 2026-11-19 · How I take in changes from Claude and Copilot

To explore (2026-11-17), after the sandbox and Copilot in Now: the agent works
in a git worktree of its own, on its own branch, so its work arrives as a real
merge request instead of unstaged changes in my tree.

- A script on the host (or `bin/nix-devcontainer.sh` with a flag) creates the
  worktree (`git worktree add ../<repo>-<task> -b agent/<task>`) and opens the
  container on it; when done, it removes the worktree, keeping the branch for
  the merge request.
- Review: as a merge request on the forge, or locally (`main...agent/<task>`
  in a diff view); the same view as for colleagues' requests, see
  "GitLab/GitHub reviews in nvim" below. The unstaged flow below (agent-review,
  staging per hunk) still works inside the worktree, for rounds before a
  commit.
- Who commits: the container has no keys, but a local commit needs none
  (unless signed). Either the agent commits in its worktree, or the host
  script does when the agent is done. Pushing stays on the host.
- Mounts: a worktree's `.git` is a file that points at
  `<repo>/.git/worktrees/<name>` by absolute path, and it shares objects, refs,
  config and hooks with the main repo. The container's paths differ: mount the
  main `.git` at the same path, or use `worktree.useRelativePaths` (git 2.48+;
  check).
- Security: a writable shared `.git` lets the agent plant hooks or config
  (`core.fsmonitor`, `core.hooksPath`, aliases) that run on the host at my
  next git command in that repo. Keep the main `.git` read-only in the
  container and commit from the host, or check what git guards itself
  (`safe.directory` checks ownership only).

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
- agent-review, a local plugin (`config/nvim/local-plugins/agent-review`,
  spec and keys in `config/nvim/lua/plugins/agent-review.lua`): `<leader>ar`
  lists the unstaged hunks and untracked files with the agent's notes from
  `.agent-notes.md` (ignored in the global `config/git/ignore`) in
  trouble.nvim, and shows the changes in the files inline or side by side
  (`<leader>as`). What it does, the notes format and its known issue (the
  preview overlaps right after toggling to side by side) are in its
  `README.md`. The keys load the plugin before trouble looks for its source,
  so they stay in its own spec, not trouble's. The name is taken on GitHub
  (joelazar/agent-review.nvim, the other direction: my comments become a
  prompt for the agent); pick another if it's ever published. The agent
  rewrites the notes every turn to describe what's still unstaged; the same
  text makes the chat summary. Rules for both in `config/claude/CLAUDE.md`.
  Try it in real rounds and adjust. Compared with existing plugins
  (2026-11-15) and kept: the closest is codediff.nvim with review.nvim (git
  diff with stage/discard per hunk, typed comments exported as markdown, no
  quickfix); an idea worth taking is code-review.nvim's comment threads that
  the agent answers through a CLI.
- Taken in; the sandbox writes in the project and not elsewhere in home
  (tested). Left: real rounds with `<leader>ar`, to see how it works out.
- Previews in trouble (seen 2026-11-15): the first one shows the file
  without syntax highlighting or gitsigns; from the second on it highlights
  partly, still not as in an open buffer, which is what I'd like. Maybe
  trouble, maybe our source: its `preview` hook and `review_buffers` load
  files into real buffers for the preview
  (`lua/trouble/sources/agent_review.lua`). Check whether a file loaded only
  for the preview gets its `filetype`, treesitter and gitsigns (they attach
  on `BufReadPost`/`FileType`), and how trouble's own modes preview.
- Stale note lines: after I reset or edit a hunk, the notes' line numbers
  still point at the old lines until the agent's next turn (seen: a 3-line
  comment reset, every later note 3 lines off). Staging doesn't cause it (it
  leaves the working tree's lines alone); resets and edits do. All in the
  plugin, no change to the notes format:
  - Done: detection (`find_stale_paths`). A file's notes are stale when the
    file was written after the notes file and its hunks no longer pair up one
    to one with its note locations; marked `⚠` in trouble, `[stale?]` in
    quickfix, a warning once per set of files. Lining up alone was fooled by
    staging (a note left without its hunk) and by a reset that lands a note
    exactly on another hunk. Specs in `tests/unit` (`make test`).
  - Parked (2026-11-15) until the detection has been tried in real rounds.
  - Then, if needed: while fresh, record each note's hunk content (removed
    and added lines, plus a few context lines), in memory and under
    `stdpath("state")`, keyed by repo and notes content.
  - After that: once stale, find each note's hunk by that content, context
    breaking ties. Its hunk edited (removed lines still match), or a tie left:
    show the note as outdated (own group in trouble), don't guess. No snapshot:
    line matching plus the stale mark, as now.
  - Specs to add with it: gitsigns-style reset in a buffer, an nvim restart
    (snapshot read back), identical hunks.

  How others do it (researched 2026-11-15): postilla.nvim (target text, sha256,
  5 context lines; extmark live, then exact search, context tie-break; none or
  tie: ⚠ stale) and code-review.nvim (text and 2 context lines; exact, moved,
  then bigram-Dice fuzzy ≥ 0.8; not found: `outdated`) match content, as we will.
  GitLab maps lines through diffs between versions (`PositionTracer`,
  `LineStrategy`) and marks notes outdated when their line left the diff; for us
  that's a git tree snapshot of the working tree and `git diff <tree>`, the
  fallback if content matching proves flaky. CodeCompanion and review.nvim keep
  line numbers (review.nvim moves them with extmarks, saved on write).
- Live reload: `:checktime` on `FocusGained`, `BufEnter` and `CursorHold`
  in `config/nvim/lua/autocommands.lua`, with a notice per reloaded file;
  `focus-events on` in `config/tmux/tmux.conf` (needs a `source-file` or a
  new tmux server). While `<leader>ar` is open, agent-review also watches
  `.agent-notes.md` and on a change reloads buffers and refreshes the list
  (`watch_notes`). Tested headless. Left: try both in a real round.
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
"Copilot CLI in the container" in Now). The agent may write in the project,
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
  through (see "Lists of results in trouble.nvim" below). Side by side,
  working tree against index: nvim's own `nvim.difftool` (loaded in
  `config/nvim/lua/plugins/difftool.lua`) or diffview.nvim, where
  `:diffget`/`:diffput` also take single lines. Pick it together with the
  forge reviews item below, so one diff view serves both.
- Also to compare: codediff.nvim (VSCode-style diff with a list of changed
  files; check). Its list of changed files is covered by `<leader>ar` in
  trouble now, which leaves codediff.nvim only its diff rendering.
- Jump between hunks: `]c`/`[c` (gitsigns' `nav_hunk`, nvim's own `]c` in a
  diff window) beside `<leader>ghn`/`<leader>ghp`
  (`config/nvim/lua/plugins/git.lua`). mini.diff overlaps gitsigns (signs,
  hunks, staging); only worth it for its overlay of the diff in the buffer,
  which gitsigns' `preview_hunk_inline` partly gives.
- Keep the agent's changes apart from mine: start from a clean tree (commit or
  stash first), or the worktree above.
- Enforce "staged means I accepted it" for every agent: `.git` read-only in
  the container (see the worktree's security point above).
- Or as git conflicts: the agent writes conflict markers, I pick a side with
  git-conflict.nvim (see its item below).
- The other way round, the agent reviewing my changes: coderabbit.nvim with
  Claude or Copilot in place of `cr`. `claude -p` (or `/code-review`), or
  `copilot -p`, on uncommitted changes or the branch against `main`, printing
  `file:line: message` lines that `:cexpr`/`:cfile` load into quickfix, or
  `vim.diagnostic.set` under its own namespace. Check whether coderabbit.nvim
  can take another CLI (`cli.binary`, `cli.extra_args`; it parses `cr`'s
  output, so likely not), else a small plugin of our own.
- Pointing the agent at code: `<leader>yr` copies `path/from/root:42`, or
  `:42-58` for a visual range (`config/nvim/lua/copy_reference.lua`, git
  root else the cwd; the root the status line in "nvim wishes" below can
  reuse); `<leader>yf` the file's path alone, `<leader>yd` its directory;
  `<leader>yR`, `<leader>yF` and `<leader>yD` the same with the absolute
  path. Maybe: the selection as a fenced code
  block with the language from `filetype` (```` ```cpp ````; a small map
  where names differ, e.g. `sh` → `bash`), the reference above it, on
  another `<leader>y` key.

Instead of or on top of that, approval per edit as it happens, from nvim:

- claudecode.nvim (coder) speaks Claude Code's IDE protocol, the one VSCode
  uses: each edit opens as a diff to accept or reject. Claude only.
- ACP (Agent Client Protocol): Copilot CLI has an ACP server (GitHub docs:
  `copilot-cli-reference/acp-server`), Claude Code works through Zed's
  adapter (`claude-agent-acp`, on the Agent SDK), and nvim clients such as
  codecompanion.nvim drive either. One front-end for both, each subscription
  in its own harness: decided (2026-11-17) for keeping work on Copilot and
  personal on Claude, with agentic.nvim in the devbox (see Now). Check
  whether the adapter counts as Claude Code under Anthropic's terms (below);
  claudecode.nvim runs the Claude Code binary itself, so it's safe either
  way. Plugins to try (2026-11-17):
  - codecompanion.nvim: adapters `claude_code` (`claude-agent-acp`) and
    `copilot_acp` (`copilot --acp --stdio`). Edits ask permission in the
    chat: `gv` shows the diff, `g1`–`g4` always/once/reject/cancel; `gty`
    switches Ask, Auto and YOLO; `/resume` loads the agent's sessions;
    `:CodeCompanionCLI` runs the agent's own TUI instead.
  - Our Claude settings through the adapter (its source, checked
    2026-11-17): it loads `settingSources` user, project and local, so
    `config/claude/settings.json` applies (deny rules, sandbox, auto mode),
    and Claude's own tools run in Claude Code, so Bash stays in bwrap. Its
    permission questions go to the client, whose YOLO and Auto modes answer
    them itself (allow once). From npm it runs the SDK's bundled `claude`;
    nixpkgs' `claude-agent-acp` wraps it with `CLAUDE_CODE_EXECUTABLE` set
    to nixpkgs' `claude-code`, so install it through nix. It offers the
    client "Bypass permissions" whenever it doesn't run as root
    (`ALLOW_BYPASS`), whatever the settings say; Claude Code then refuses
    the switch, as `permissions.disableBypassPermissionsMode` is
    `"disable"` (tried 2026-11-19: agentic shows "rejected because of
    internal error"). That setting also blocks
    `--dangerously-skip-permissions`; revisit for the box, see "Inside, the
    agent may skip its own prompts" in Now. CLAUDE.md, `TODO.md` and memory
    load as in the CLI (checked 2026-11-19). Effort: the adapter takes the
    starting level from a top-level `effortLevel` only, not from
    `modelSettings`, so ours (`high` for Opus) doesn't reach it; it falls
    back to `xhigh`, else `high` (its source). Copilot CLI gets none of
    this: its own rules, the container as the boundary.
  - agentic.nvim (carlos-algms): ACP only, providers `claude-agent-acp` and
    `copilot-acp`; edits as split or inline diff (`]c`/`[c`), permission
    buttons; sessions shared with the terminal CLI. Needs nvim 0.11.
    Decided (2026-11-17), as the thinner wrapper. Its source (checked
    2026-11-17): it offers the agent no file or terminal access of its
    own and sends no `_meta`, so Claude does all edits and commands
    itself under our settings; every permission question waits for me (no
    auto-approve); the agent inherits nvim's whole environment, plus
    `CLAUDE_CODE_ENTRYPOINT=agentic-nvim` so `claude --resume` sees its
    sessions. `<S-Tab>` cycles the agent's modes, which can land on
    "Bypass permissions" (refused, see above), and a provider's
    `default_mode` sets one per session. Effort per session:
    `<localleader>t` picks it (the adapter's `effort` config option),
    `default_thought_level` in the provider's config sets it at start. It
    installs neither adapters nor agents ("for security reasons"):
    `claude-agent-acp` and `copilot` come from nix. On trial on the host
    (2026-11-19): spec and keys in `config/nvim/lua/plugins/agentic.lua`
    (`<leader>aa` chat, `<leader>ac` add context; loads only where
    `claude-agent-acp` is on `PATH`), adapter in `home/modules/claude.nix`;
    render-markdown draws the chat (`AgenticChat` in its `file_types`, in
    `config/nvim/lua/plugins/markdown.lua`). Sessions start in auto mode.
    Left: `:checkhealth agentic`, whether `/effort` is among its slash
    commands, then real rounds beside the terminal CLI. In its buffers
    `<localleader>` is our space, so its `<localleader>l`/`m`/`o`/`t`
    shadow those `<leader>` groups there.
  - sidekick.nvim (folke): the real CLIs (`claude`, `copilot`) in a
    terminal, with keys to send the file, selection or diagnostics;
    sessions in tmux survive restarts. No adapter, so no terms question.
    Its Copilot next-edit suggestions need the Copilot language server.
  - Also listed: avante.nvim (Cursor-like sidebar, ACP among its
    providers), hermes.nvim (Ruddickmg; new, check).
  - The adapter's npm name: `@zed-industries/claude-agent-acp` in
    codecompanion's guide, `@agentclientprotocol/claude-agent-acp` in
    agentic's; check which is current.

Claude subscription outside Claude Code (checked 2026-11-17): not allowed.
Anthropic's legal page (code.claude.com, "Legal and compliance") limits plan
logins to Claude Code and its own apps; third-party apps may not route requests
through plan credentials. Enforced since 2026-04-04, with such use billed as
extra usage; OpenCode dropped its Claude login after legal demands (2026-03).
Plan logins in the Agent SDK and `claude -p` still draw from plan limits
(support article, update 2026-10-07). So in Pi or OpenCode, Claude means an API
key (per token), or Claude models through Copilot.

One harness for both, e.g. Pi (earendil-works/pi, was badlogic/pi-mono): a
minimal agent CLI you extend yourself (extensions, skills, prompt templates; an
RPC mode over JSONL for editors, and a TypeScript SDK). It takes a Copilot token
(`COPILOT_GITHUB_TOKEN`) and Anthropic credentials (`ANTHROPIC_API_KEY` or
`ANTHROPIC_OAUTH_TOKEN`; it still offers a Claude Pro/Max login, which the terms
above rule out). OpenCode is the other candidate: GitHub supports it officially
with Copilot Pro, Pro+, Business and Enterprise (changelog 2026-01-16); ask
whether the work org allows it. Out of the box Pi has no permission system or
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

Then:

- The same write rules for Copilot as for Claude (see the easy path above).
- Rewrite the rules in `config/claude/CLAUDE.md` (or the shared `AGENTS.md`)
  to match what we pick.

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
  The path is also what the copy-a-reference keys in "How I take in
  changes" above use. Look into how to show which window is current once
  windows have no status line of their
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
Copilot" above: ideally the same diff view and quickfix flow for an agent's
changes and a colleague's request. Candidates: octo.nvim (GitHub only; PRs,
review threads, through the `gh` CLI) and harrisoncramer/gitlab.nvim (GitLab
only; MR comments and approvals, on diffview.nvim, with a small Go server it
builds; check). Neither covers both; just reading a diff works for either with the
branch fetched and a local diff view. Check first which forge work uses, and
whether it's a self-hosted GitLab. Tokens: same question as "Copilot CLI in
the container" (sops through `nixfiles-secrets`), plus `gh`/`glab auth`.

### 2026-11-14 · Lists of results in trouble.nvim

Decided: trouble everywhere a list is to work through. It's installed
(`config/nvim/lua/plugins/trouble.lua`) and shows the agent's changes
(`<leader>ar`); next are the LSP results (references first), then diagnostics.
What's below was the comparison; trim it as the lists move.

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
  `:cfile` and `:Gitsigns setqflist` use. nvim-bqf's preview pops up as a
  float, which I found annoying in the agent review; trouble previews in
  the main window instead.
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
- Open: whether quickfix keeps a role beside trouble (`:cdo`, editing hits
  with quicker), and whether nvim-bqf stays at all.
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
