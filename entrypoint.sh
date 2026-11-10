#!/bin/bash
set -e

# Default values if not explicitly provided
SERVER_NAME="${SERVER_NAME:-pzserver}"
ADMIN_PASSWORD="${ADMIN_PASSWORD:-ChangeMe123!}"
AUTO_UPDATE="${AUTO_UPDATE:-true}"
STEAM_BRANCH="${STEAM_BRANCH:-public}"
SERVER_RAM_MIN="${SERVER_RAM_MIN:-4g}"
SERVER_RAM_MAX="${SERVER_RAM_MAX:-8g}"

INSTALL_DIR="/home/steam/pz-server"
DATA_DIR="/home/steam/Zomboid"
CONFIG_DIR="${DATA_DIR}/Server"
INI_FILE="${CONFIG_DIR}/${SERVER_NAME}.ini"
CONSOLE_PIPE="/tmp/pz_console"

echo "=========================================================="
echo " Starting Project Zomboid Dedicated Server"
echo " Server Name : ${SERVER_NAME}"
echo " Branch      : ${STEAM_BRANCH}"
echo " RAM Min/Max : ${SERVER_RAM_MIN} / ${SERVER_RAM_MAX}"
echo " Auto-Update : ${AUTO_UPDATE}"
echo "=========================================================="

# Pre-flight volume write check (prevents silent Linux permission failures)
if [ ! -w "${DATA_DIR}" ] 2>/dev/null || [ ! -w "${INSTALL_DIR}" ] 2>/dev/null; then
    echo "[ERROR] Cannot write to persistent volumes (${DATA_DIR} or ${INSTALL_DIR})."
    echo "        Directories are not writable by container user steam (UID 1000)."
    echo "[HINT] On Linux hosts, fix folder ownership by running:"
    echo "       sudo chown -R 1000:1000 ./data"
    exit 1
fi

# 1. Install or Update Server files via SteamCMD
if [ "${AUTO_UPDATE}" = "true" ] || [ ! -f "${INSTALL_DIR}/start-server.sh" ]; then
    echo "[INFO] Updating/Installing Project Zomboid server files (App ID: 380870)..."
    STEAM_ARGS="+force_install_dir ${INSTALL_DIR} +login anonymous +app_update 380870"

    if [ -n "${STEAM_BRANCH}" ] && [ "${STEAM_BRANCH}" != "public" ]; then
        echo "[INFO] Targeting Steam branch: ${STEAM_BRANCH}"
        STEAM_ARGS="${STEAM_ARGS} -beta ${STEAM_BRANCH}"
        if [ -n "${STEAM_BRANCH_PASSWORD}" ]; then
            STEAM_ARGS="${STEAM_ARGS} -betapassword ${STEAM_BRANCH_PASSWORD}"
        fi
    else
        echo "[INFO] Targeting stable branch (public)"
    fi

    STEAM_ARGS="${STEAM_ARGS} validate +quit"
    /home/steam/steamcmd/steamcmd.sh ${STEAM_ARGS}
else
    echo "[INFO] AUTO_UPDATE is false and server files exist. Skipping SteamCMD update."
fi

# 2. Configure Memory / RAM in ProjectZomboid64.json
JSON_CONFIG="${INSTALL_DIR}/ProjectZomboid64.json"
if [ -f "${JSON_CONFIG}" ]; then
    echo "[INFO] Applying JVM memory limits to ProjectZomboid64.json (-Xms${SERVER_RAM_MIN}, -Xmx${SERVER_RAM_MAX})..."
    sed -i -E "s/\"-Xmx[0-9]+[a-zA-Z]*\"/\"-Xmx${SERVER_RAM_MAX}\"/g" "${JSON_CONFIG}"
    if grep -q "\"-Xms" "${JSON_CONFIG}"; then
        sed -i -E "s/\"-Xms[0-9]+[a-zA-Z]*\"/\"-Xms${SERVER_RAM_MIN}\"/g" "${JSON_CONFIG}"
    else
        sed -i -E "s/(\"-Xmx[0-9]+[a-zA-Z]*\")/\"-Xms${SERVER_RAM_MIN}\", \1/g" "${JSON_CONFIG}"
    fi
fi

# 3. Create Server Configuration and Sync Environment Variables
mkdir -p "${CONFIG_DIR}"
touch "${INI_FILE}"

set_ini() {
    local key="$1"
    local val="$2"
    # Safely escape backslashes, ampersands, and pipes for sed substitution
    local esc_val
    esc_val=$(printf '%s\n' "${val}" | sed -e 's/[\\&|]/\\&/g')
    if grep -q "^${key}=" "${INI_FILE}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${esc_val}|" "${INI_FILE}"
    else
        echo "${key}=${val}" >> "${INI_FILE}"
    fi
}

echo "[INFO] Synchronizing environment variables with ${INI_FILE}..."
set_ini "DefaultPort"                  "${SERVER_PORT:-16261}"
set_ini "UDPPort"                      "${STEAM_PORT:-16262}"
set_ini "RCONPort"                     "${RCON_PORT:-27015}"
set_ini "RCONPassword"                 "${RCON_PASSWORD:-}"
set_ini "Public"                       "${PUBLIC:-true}"
set_ini "PublicName"                   "${SERVER_PUBLIC_NAME:-Project Zomboid Server}"
set_ini "PublicDescription"            "${SERVER_PUBLIC_DESC:-Hosted with Docker}"
set_ini "ServerWelcomeMessage"         "${SERVER_WELCOME_MESSAGE:-Welcome to Project Zomboid!}"
set_ini "Password"                     "${SERVER_PASSWORD:-}"
set_ini "MaxPlayers"                   "${MAX_PLAYERS:-16}"
set_ini "PingLimit"                    "${PING_LIMIT:-400}"
set_ini "PVP"                          "${PVP:-true}"
set_ini "PauseEmpty"                   "${PAUSE_EMPTY:-true}"
set_ini "GlobalChat"                   "${GLOBAL_CHAT:-true}"
set_ini "Open"                         "${OPEN:-true}"
set_ini "AutoCreateUserInWhiteList"    "${AUTO_CREATE_USER_IN_WHITELIST:-true}"
set_ini "SleepAllowed"                 "${SLEEP_ALLOWED:-false}"
set_ini "SleepNeeded"                  "${SLEEP_NEEDED:-false}"
set_ini "SafetySystem"                 "${SAFETY_SYSTEM:-true}"
set_ini "ShowSafety"                   "${SHOW_SAFETY:-true}"
set_ini "SafetyToggleTimer"            "${SAFETY_TOGGLE_TIMER:-2}"
set_ini "SafetyCooldownTimer"          "${SAFETY_COOLDOWN_TIMER:-120}"
set_ini "SpawnPoint"                   "${SPAWN_POINT:-0,0,0}"
set_ini "SpeedLimit"                   "${SPEED_LIMIT:-70.0}"
set_ini "HoursForLootRespawn"          "${HOURS_FOR_LOOT_RESPAWN:-0}"
set_ini "MinutesPerPage"               "${MINUTES_PER_PAGE:-1.0}"
set_ini "SaveWorldEveryMinutes"        "${SAVE_WORLD_EVERY_MINUTES:-15}"
set_ini "TrashDeleteAll"               "${TRASH_DELETE_ALL:-false}"
set_ini "DropOffWhiteListAfterDeath"   "${DROP_OFF_WHITELIST_AFTER_DEATH:-false}"
set_ini "Mods"                         "${MOD_NAMES:-}"
set_ini "Map"                          "${MAP:-Muldraugh, KY}"
set_ini "WorkshopItems"                "${WORKSHOP_IDS:-}"
set_ini "SteamScoreboard"              "${STEAM_SCOREBOARD:-true}"
set_ini "SteamVAC"                     "${STEAM_VAC:-true}"
set_ini "UPnP"                         "${UPNP:-false}"
set_ini "VoiceEnable"                  "${VOICE_ENABLE:-true}"
set_ini "VoiceMinDistance"             "${VOICE_MIN_DISTANCE:-10.0}"
set_ini "VoiceMaxDistance"             "${VOICE_MAX_DISTANCE:-30.0}"
set_ini "Voice3D"                      "${VOICE_3D:-true}"
set_ini "DenySameIP"                   "${DENY_SAME_IP:-true}"
set_ini "DoLuaChecksum"                "${DO_LUA_CHECKSUM:-true}"

# 4. Named pipe FIFO setup for interactive console & graceful shutdown
rm -f "${CONSOLE_PIPE}"
mkfifo "${CONSOLE_PIPE}"
chmod 666 "${CONSOLE_PIPE}"
# Keep descriptor 3 open so FIFO doesn't send EOF
exec 3<>"${CONSOLE_PIPE}"

graceful_shutdown() {
    echo ""
    echo "[INFO] Termination signal received. Saving world and stopping server..."
    echo "servermsg \"Server shutting down for restart/stop...\"" >&3 2>/dev/null || true
    echo "save" >&3 2>/dev/null || true
    sleep 2
    echo "quit" >&3 2>/dev/null || true

    if [ -n "${SERVER_PID}" ]; then
        local count=0
        while kill -0 "${SERVER_PID}" 2>/dev/null && [ "$count" -lt 25 ]; do
            sleep 1
            count=$((count + 1))
        done
        if kill -0 "${SERVER_PID}" 2>/dev/null; then
            echo "[WARN] Server process did not stop within 25s. Sending SIGTERM..."
            kill -TERM "${SERVER_PID}" 2>/dev/null || true
        fi
        wait "${SERVER_PID}" 2>/dev/null || true
    fi
    echo "[INFO] Project Zomboid server has shut down safely."
    exit 0
}

trap 'graceful_shutdown' SIGTERM SIGINT

# 5. Launch the Dedicated Server
echo "[INFO] Launching Project Zomboid dedicated server..."
cd "${INSTALL_DIR}"

./start-server.sh \
    -servername "${SERVER_NAME}" \
    -cachedir="${DATA_DIR}" \
    -adminpassword "${ADMIN_PASSWORD}" \
    <&3 &

SERVER_PID=$!

# Wait for process
wait "${SERVER_PID}"
