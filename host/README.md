# Host-level setup

Every target is plain Ubuntu managed by standalone Home Manager, which runs
unprivileged. Anything root-owned outside `$HOME` cannot be a module, so it
lives here as data plus an apply step in `bin/host-setup.sh`.

    host-setup.sh          # report what is missing
    host-setup.sh apply    # install it, prompts for sudo

Profiles that need one of these fixes call the matching `check_*` from
`lib/host.sh` in their `preflight.sh`, so `nix-switch.sh` warns on every
activation instead of leaving it to be rediscovered.

Hooks do not inherit automatically the way `default.nix` imports do — a profile
built on another calls `inherit_profile_prerequisites`, which is how `lely`
picks up the checks `personal` declares.

## Fixes

### bwrap / AppArmor — the sandbox agent CLIs run shell commands in

**Symptom:** every Claude Code Bash command fails instantly with

```
bwrap: loopback: Failed RTM_NEWADDR: Operation not permitted
```

**Cause:** Ubuntu 24.04 ships `kernel.apparmor_restrict_unprivileged_userns=1`.
A binary with no AppArmor profile of its own is transitioned into
`/etc/apparmor.d/unprivileged_userns` when it creates a user namespace, and
that profile opens with `audit deny capability` — all capabilities stripped
inside. bwrap keeps its namespaces but loses `CAP_NET_ADMIN` and
`CAP_SYS_ADMIN`, so it can neither bring loopback up nor bind-mount.
`config/claude/settings.json` sets `failIfUnavailable: true` and
`allowUnsandboxedCommands: false`, so there is no fallback and every command
dies.

**Fix:** `host/apparmor.d/bwrap` grants bwrap `userns`, the pattern Ubuntu
ships for Chrome and Steam.

**Trade-off, accepted deliberately:** this re-opens unprivileged user
namespaces for one binary. That kernel restriction exists because userns have
been a recurring local privilege-escalation vector, and bwrap's whole purpose
is handing out namespaces, so anything that can exec it inherits the reach.
Taken anyway: without it the sandbox does not run at all, and that sandbox is
the only thing enforcing the `denyWrite` and network-allowlist rules against
arbitrary shell commands. The `permissions.deny` list is per-tool and is not a
substitute.

**Gotcha:** AppArmor profiles are anchored to an absolute path. This one
targets `/usr/bin/bwrap` from Ubuntu's `bubblewrap` package. If bwrap ever
resolves to a nix-store path the profile silently stops applying, and the
store path changes on every update — `check_bwrap_sandbox` warns when the
bwrap first on PATH is not the anchored one.
