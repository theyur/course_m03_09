# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Minimal ASP.NET Core Web API (.NET 10), generated from the default template with Swagger/OpenAPI added. Single project, no tests yet — `Program.cs` defines everything (top-level statements, minimal API endpoints).

## Commands

```bash
dotnet build                    # Build
dotnet run                      # Run (uses launchSettings.json "http" profile: http://localhost:5000)
dotnet watch run                # Run with hot reload
```

There is no test project yet. If one is added, standard `dotnet test` conventions apply.

Endpoint requests can be exercised via `ClaudeCodeProdSetupTest.http` (VS Code/Rider REST client format) or via Swagger UI, served at `/swagger` when running in the Development environment.

## Architecture

- `Program.cs` — entire app: builder/service registration, middleware pipeline, and endpoint(s) defined with minimal APIs (`app.MapGet(...)`). New endpoints should follow this same top-level-statements, minimal-API style unless the project grows enough to warrant splitting into controllers/services.
- OpenAPI is registered twice for different purposes: `AddOpenApi()`/`MapOpenApi()` (built-in ASP.NET Core OpenAPI document generation) and `AddSwaggerGen()`/`UseSwagger()`/`UseSwaggerUI()` (Swashbuckle, providing the interactive Swagger UI). Service registration is unconditional; only the endpoints and UI are gated behind `app.Environment.IsDevelopment()`.
- Configuration follows standard ASP.NET Core layering: `appsettings.json` + `appsettings.Development.json`, with `ASPNETCORE_ENVIRONMENT` set via `Properties/launchSettings.json` (local run) or the devcontainer's `containerEnv` (container run).

## Devcontainer

The repo is designed to run inside `.devcontainer/` (see `devcontainer.json`): forwards port 5000, sets `ASPNETCORE_URLS=http://0.0.0.0:5000` and `ASPNETCORE_ENVIRONMENT=Development` in-container, and runs `init-firewall.sh` on start. Claude Code config is bind-mounted from `.claude-user` on the host.

See [.claude/README.md](.claude/README.md) for sandbox permissions and .NET compatibility settings.
