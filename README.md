# Project Zomboid Dedicated Server

A Docker container to easily host and manage Project Zomboid dedicated servers with Docker Compose or Portainer. Handles SteamCMD installation and updates automatically, configures server options via environment variables, and saves world state cleanly on shutdown.

## Quick Start

### 1. Configure and start

```bash
# Optional: copy configuration template to customize settings
cp .env.example .env

# Start the server
docker compose up -d
```

On first run, SteamCMD downloads the game server files (~3-5 GB). This takes a few minutes depending on your connection.

### 2. Check status and logs

Check container health:
```bash
docker compose ps
```
The status starts as `(health: starting)` while SteamCMD runs and changes to `(healthy)` when the server process is up.

View console output:
```bash
docker compose logs -f
```
The server is ready when `*** SERVER STARTED ****` appears in the log.

### 3. Connect

In Project Zomboid, go to **Join** and enter your server IP:
- Port: `16261`
- Username: your chosen username (use `admin` for administrator access)
- Password: your chosen password (or `ADMIN_PASSWORD` from `.env`)

## Portainer

To deploy via Portainer Stacks:

1. In Portainer, go to **Stacks** > **Add stack**.
2. Name the stack (e.g. `pz-server`).
3. Select **Web editor** and paste the contents of `docker-compose.yml`.
4. (Optional) Set environment variables (such as `ADMIN_PASSWORD` or `SERVER_RAM_MAX`).
5. Click **Deploy the stack**.

If using `portainer-template.json`, update `repository.url` inside the file to your repository URL before importing it as a custom App Template.

## Linux Host Permissions

On Linux hosts, Docker creates volume directories as root if they do not exist yet. Since the container runs as unprivileged user `steam` (UID 1000), set permissions before starting:

```bash
mkdir -p data/server data/install
sudo chown -R 1000:1000 data
```

## Configuration

Settings are controlled through environment variables in `.env`.

| Variable | Default | Description |
|---|---|---|
| `SERVER_NAME` | `pzserver` | Profile name (save folder and config name) |
| `ADMIN_PASSWORD` | `ChangeMe123!` | In-game password for user `admin` |
| `SERVER_PASSWORD` | | Password required for players to join (blank = none) |
| `SERVER_RAM_MIN` | `4g` | Minimum JVM memory allocation |
| `SERVER_RAM_MAX` | `8g` | Maximum JVM memory ceiling |
| `SERVER_PORT` | `16261` | Primary game client port (UDP) |
| `STEAM_PORT` | `16262` | Steam query port (UDP) |
| `RCON_PORT` | `27015` | Remote administration port (TCP) |
| `PUBLIC` | `true` | List server in public browser |
| `PVP` | `true` | Enable player-versus-player damage |
| `PAUSE_EMPTY` | `true` | Pause world simulation when no players are connected |
| `MAX_PLAYERS` | `16` | Maximum concurrent players |
| `AUTO_UPDATE` | `true` | Check and download Steam updates on container restart |
| `STEAM_BRANCH` | `public` | Steam branch (`public` for stable, `b42_beta` or `unstable` for beta) |
| `WORKSHOP_IDS` | | Semicolon-separated Steam Workshop item IDs |
| `MOD_NAMES` | | Semicolon-separated Mod IDs matching the workshop items |

See `.env.example` for the complete list of options.

## Server Commands and Backups

### Live console commands

Send console commands to the running server:

```bash
# Broadcast a chat message
docker exec project-zomboid-server pz-cmd 'servermsg "Hello survivors!"'

# List online players
docker exec project-zomboid-server pz-cmd players

# Save world state
docker exec project-zomboid-server pz-cmd save

# Grant admin rights
docker exec project-zomboid-server pz-cmd 'setaccesslevel "Username" "admin"'
```

### World backups

Create a timestamped backup while the server is running:

```bash
docker exec project-zomboid-server pz-backup
```

This triggers a world save and archives `Saves/`, `Server/`, and `db/` into `./data/server/Backups/` on the host.

## Workshop Mods

1. Find the mod on Steam Workshop and get its Workshop ID and Mod ID.
2. In `.env`, add them separated by semicolons:
   ```env
   WORKSHOP_IDS=2392709985;2688809240
   MOD_NAMES=Arsenal(26)GunFighter;Brita;
   ```
3. Restart the container:
   ```bash
   docker compose restart
   ```
SteamCMD downloads the workshop files automatically during startup.

## Sandbox Settings

Gameplay rules (zombie lore, loot rarity, water/power cutoff, infection) are stored in `_SandboxVars.lua`:

1. Start a Singleplayer game in Project Zomboid and choose **Custom Sandbox**.
2. Configure your desired rules and save the preset (e.g. `MyRules`).
3. Copy the generated file:
   - Windows: `%USERPROFILE%\Zomboid\Server\MyRules_SandboxVars.lua`
   - Linux: `~/Zomboid/Server/MyRules_SandboxVars.lua`
4. Place it in `./data/server/Server/pzserver_SandboxVars.lua` (match your `SERVER_NAME`).
5. Restart the server (`docker compose restart`).

## Network Ports

Forward these ports on your router to the host machine for outside players:

- `16261 UDP` - Game client traffic
- `16262 UDP` - Steam query and direct connect
- `27015 TCP` - RCON remote administration (optional)
