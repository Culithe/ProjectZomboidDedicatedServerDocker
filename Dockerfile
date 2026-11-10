FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies for SteamCMD and 64-bit Project Zomboid Dedicated Server
RUN dpkg --add-architecture i386 && \
    apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        locales \
        lib32gcc-s1 \
        lib32stdc++6 \
        libc6-i386 \
        libpulse0 \
        libasound2 \
        binutils \
        procps \
        sed \
        && \
    echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && \
    locale-gen && \
    rm -rf /var/lib/apt/lists/* && \
    useradd -m -u 1000 -s /bin/bash steam

ENV LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Prepare folders
RUN mkdir -p /home/steam/steamcmd /home/steam/pz-server /home/steam/Zomboid /scripts && \
    chown -R steam:steam /home/steam

# Download and unpack SteamCMD as steam user
USER steam
WORKDIR /home/steam/steamcmd
RUN curl -fsSL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar -zxvf -

# Copy startup script and management utilities
USER root
COPY entrypoint.sh /scripts/entrypoint.sh
COPY scripts/pz-cmd /usr/local/bin/pz-cmd
COPY scripts/pz-backup /usr/local/bin/pz-backup

RUN sed -i 's/\r$//' /scripts/entrypoint.sh /usr/local/bin/pz-cmd /usr/local/bin/pz-backup && \
    chmod +x /scripts/entrypoint.sh /usr/local/bin/pz-cmd /usr/local/bin/pz-backup && \
    chown -R steam:steam /scripts

USER steam
WORKDIR /home/steam

# Project Zomboid ports (Game UDP, Steam Query UDP, RCON TCP)
EXPOSE 16261/udp 16262/udp 27015/tcp

ENTRYPOINT ["/scripts/entrypoint.sh"]
