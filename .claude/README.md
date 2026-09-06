# Claude Code sandbox: development baseline

The shared .claude/settings.json and this checkout's ignored .claude-user/settings.json
carry the same policy. Start Claude from /workspace. Restart Claude after changes.

## Allowed development workflow

Sandboxed commands and source edits are automatically approved. Build, restore,
run, watch, test, format, shell utilities, web tools and read-only Git/Docker commands
are available. Localhost HTTP and Unix sockets are permitted. /tmp is writable,
including .NET's hardcoded /tmp/.dotnet shared-memory path.

## Restrictions

.NET user-secret directories are denied to both Claude file tools and sandboxed
subprocesses. dotnet user-secrets commands are denied. The policy covers the normal
vscode home, Claude's separate .NET home and root's user-secret directory.

Git reset, clean, restore, checkout, rm, rebase and push are denied, along with
branch/tag deletion and stash drop/clear. This deliberately blocks these whole
subcommands rather than attempting to distinguish destructive flags. Git status,
diff, log, add and commit have no explicit deny; Claude's built-in protections may
still constrain writes to Git metadata.

Docker removal, prune, stop and kill commands, and Compose down/removal/stop/kill
commands are denied. Inspection commands have no explicit deny. Docker access still
depends on the container exposing a Docker endpoint; this setup does not add one.

Command patterns are guardrails, not a guarantee against equivalent operations
inside scripts or SDKs. In particular, Unix socket access supports normal IPC
but can also reach any service socket explicitly mounted into the container.
Do not mount a Docker daemon socket expecting command-pattern rules to isolate it.

Sandboxing remains enabled with no unsandboxed retry and no weaker nested mode.
Claude/runtime built-in protected paths still apply. Developer-run terminals and
Rider are unaffected. Secrets supplied through environment variables, logs, prompts,
or nonstandard locations are outside the file restrictions described here.

## .NET compatibility

Claude's environment uses a separate DOTNET_CLI_HOME and artifact directory under
/home/vscode/.cache/claude-dotnet, with the shared NuGet package cache. This avoids
conflicts with Windows/Rider outputs. MSBuild source-control metadata discovery and
SourceLink remain disabled in Claude builds because the runtime itself protects
.gitmodules. Human builds keep their defaults.

The firewall remains unchanged; the sandbox domain list mirrors its domains plus
localhost and 127.0.0.1. Keep the lists synchronized when changing the firewall.

## Container startup

The approved seccomp profile remains enabled. devcontainer.json embeds the compact
JSON from seccomp-bwrap.json because Rider sends it directly to Docker's API.
For manual docker CLI commands use the JSON file path instead. Keep the embedded
profile and source file synchronized when editing them.

The profile is based on https://raw.githubusercontent.com/moby/profiles/main/seccomp/default.json
(retrieved 2026-09-06), with clone, unshare, mount, umount2, pivot_root and setns
allowed for Bubblewrap. Other Docker filtering remains; privileged mode and
SYS_ADMIN are not enabled. Recreate the container after changing this profile.
Settings-only changes need a Claude restart, not an image rebuild.

## Verification

Validated with the sandbox runtime: build, test command (no test project yet), API startup and HTTP response, plus denial of a dummy user-secret read.

In Claude, use /status, /permissions and /sandbox to inspect loaded settings.
Do not retain old deny rules in .claude/settings.local.json: permission lists merge.
