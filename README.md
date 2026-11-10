# Project Zomboid Dedicated Server

Run a Project Zomboid dedicated server using Docker or Portainer. Handles SteamCMD installs and updates automatically, lets you configure everything through `.env`, and saves the world cleanly on shutdown so you don't lose progress.

## Quick Start (Docker Compose)

```bash
# 1. Clone the repo
git clone https://github.com/Culithe/ProjectZomboid.git
cd ProjectZomboid

# 2. Set your passwords and settings
cp .env.example .env

# 3. Build and run
docker compose up -d --build
```

> **Note:** First startup pulls around 4 GB of game files through SteamCMD. Give it 2–5 minutes depending on your internet speed.

### Check if it's running

Follow the server log:
```bash
docker compose logs -f
```
Once you see `*** SERVER STARTED ***`, the server is online.

### Connect in-game

In Project Zomboid, click **Join**:
- **IP:** your server host IP
- **Port:** `16261`
- **Username / Password:** your choice (log in as `admin` with your `ADMIN_PASSWORD` to manage the server)

---

## Portainer Setup

### Recommended: Deploy via Git Stack

Because this setup builds its image with a Dockerfile, deploying from Git is the easiest way:

1. In Portainer, go to **Stacks** > **Add stack**.
2. Select **Repository**.
3. **Repository URL:** `https://github.com/Culithe/ProjectZomboid`
4. **Compose path:** `docker-compose.yml`
5. Under **Environment variables**, set values like `ADMIN_PASSWORD` or `SERVER_RAM_MAX`.
6. Click **Deploy the stack**. Portainer clones the repo, builds the image, and starts the container.

### Alternative: Custom App Template

If you prefer 1-click deploys with a web form:

1. In Portainer, head to **Settings** > **App Templates**.
2. Set the custom template URL:
   ```
   https://raw.githubusercontent.com/Culithe/ProjectZomboid/main/portainer-template.json
   ```
3. Save settings, go to **App Templates**, pick **Project Zomboid Dedicated Server**, fill in your passwords, and deploy.

---

## Linux File Permissions

On Linux hosts, Docker makes volume folders as root by default. The container runs as the `steam` user (UID 1000). If the server fails on first boot with permission errors, run this on your host:

```bash
mkdir -p data/server data/install
sudo chown -R 1000:1000 data
```

---

## Common Settings

All settings live in `.env`. Copy `.env.example` to get started.

| Setting | Default | What it does |
|---|---|---|
| `SERVER_NAME` | `pzserver` | Name for save files and configs |
| `ADMIN_PASSWORD` | `ChangeMe123!` | In-game password for the `admin` account |
| `SERVER_PASSWORD` | *(empty)* | Password needed for players to join |
| `SERVER_RAM_MIN` | `4g` | Minimum memory allocation |
| `SERVER_RAM_MAX` | `8g` | Maximum memory limit |
| `SERVER_PORT` | `16261` | Main game port (UDP) |
| `STEAM_PORT` | `16262` | Steam query port (UDP) |
| `PUBLIC` | `true` | Show server in the in-game public browser |
| `PVP` | `true` | Allow PvP combat |
| `PAUSE_EMPTY` | `true` | Pauses world time when no players are logged on |
| `AUTO_UPDATE` | `true` | Check for game updates every time container restarts |
| `WORKSHOP_IDS` | *(empty)* | Semicolon-separated Steam Workshop item IDs |
| `MOD_NAMES` | *(empty)* | Semicolon-separated Mod IDs matching the workshop items |

Check `.env.example` for the full list of supported variables.

---

## Server Commands & Backups

### Run in-game commands from the terminal

You can send commands directly to the live server console:

```bash
# Announce a message
docker exec project-zomboid-server pz-cmd 'servermsg "Server restarting in 5 minutes!"'

# List active players
docker exec project-zomboid-server pz-cmd players

# Force a world save
docker exec project-zomboid-server pz-cmd save

# Give admin access to someone
docker exec project-zomboid-server pz-cmd 'setaccesslevel "PlayerName" "admin"'
```

### Make a world backup

Create an instant compressed backup while the server is running:

```bash
docker exec project-zomboid-server pz-backup
```

Backups are saved to `./data/server/Backups/` on your host.

---

## Adding Mods

1. Find the mod on the Steam Workshop. Grab both the **Workshop ID** and **Mod ID** from the mod description.
2. Add them to `.env` separated by semicolons:
   ```env
   WORKSHOP_IDS=2392709985;2688809240
   MOD_NAMES=Arsenal(26)GunFighter;Brita;
   ```
3. Restart the container:
   ```bash
   docker compose restart
   ```
SteamCMD will download the mods on boot.

---

## Custom Sandbox Rules

To customize loot rarity, zombie speed, water/power shutoff, or infection:

1. In Project Zomboid (game client), start a solo game under **Custom Sandbox**.
2. Tweak your settings and save the preset as `MyRules`.
3. Grab the saved file:
   - Windows: `%USERPROFILE%\Zomboid\Server\MyRules_SandboxVars.lua`
   - Linux: `~/Zomboid/Server/MyRules_SandboxVars.lua`
4. Copy it to your server data folder as `./data/server/Server/pzserver_SandboxVars.lua` (match your `SERVER_NAME`).
5. Restart the server (`docker compose restart`).

---

## Port Forwarding

If hosting at home, forward these UDP/TCP ports on your router:

- `16261 UDP` — Player connection
- `16262 UDP` — Steam query
- `27015 TCP` — RCON remote admin (optional)

---

## License

MIT License. See [LICENSE](LICENSE) for details.
