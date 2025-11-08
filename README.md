# Toolbelt

Small set of utilities I actually use day-to-day.
Each script is short, focused, and solves a “real” recurring friction point.

## gitconfig.ps1

Opinionated Git bootstrapper.

**Purpose**: Establish a global baseline for Git, while still allowing local machine-specific overrides.

* Configures global sane defaults
* Installs human-friendly aliases
* Sets up identity routing (`includeIf`) for multiple remotes (Pro / Personal / School)
* Fallback identity is “joblu”
* Optional mode: apply large-repo optimizations to one repo only (fsmonitor, untrackedCache)

**Usage**

```powershell
./gitconfig.ps1
./gitconfig.ps1 -RepoPath ".../huge-repo"
```

## plex_unwatched.ps1

Show backlog visualizer for TV libraries via Plex API.

**Purpose**: Visualise Plex backlog and sort by unwatched count.

* Queries a TV library
* Sorts shows by count of unwatched episodes
* Prints a compact color-coded table

**Usage**

```powershell
./plex_unwatched.ps1 -Lower 0 -Upper 200 -RedLimit 100
```

Optional flags for host/port/token if not local.