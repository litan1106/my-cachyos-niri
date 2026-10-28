#!/bin/bash

# Install Docker Engine + the Compose and Buildx CLI plugins on CachyOS + niri,
# and let the current user run `docker` without sudo. Requires sudo.
#
# Notes for this machine (verified):
#   - docker, docker-compose and docker-buildx come from the sync repos. On Arch
#     they install as CLI plugins, so the commands are `docker compose` and
#     `docker buildx` (no hyphen).
#   - The root filesystem is btrfs. Docker's default overlay2 storage driver
#     works on btrfs on this kernel, so no storage-driver override is needed.
#   - The host firewall is ufw with DEFAULT_FORWARD_POLICY=DROP. Docker adds its
#     own FORWARD rules ahead of ufw's, so containers get outbound internet and
#     Waydroid's ufw route rules (fix-waydroid-firewall.sh) keep working. The
#     catch: ports published with -p bypass ufw (see the end-of-script notes).
#   - We enable docker.socket, not docker.service: the daemon starts on the
#     first `docker` command instead of at every boot.

set -e

daemon_json="/etc/docker/daemon.json"

echo "Installing Docker Engine, Compose and Buildx..."

# --needed makes a re-run a no-op for anything already installed.
sudo pacman -S --needed --noconfirm \
  docker docker-compose docker-buildx

# Cap container log size. The default json-file driver never rotates, so a
# chatty container can fill the disk. Only written if absent so a hand-edited
# config is never clobbered.
if [[ -f $daemon_json ]]; then
  echo "$daemon_json already exists — leaving it alone."
else
  echo "Writing $daemon_json (log rotation: 3 x 10 MB per container)..."
  sudo mkdir -p /etc/docker
  sudo tee "$daemon_json" >/dev/null <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
fi

echo "Enabling docker.socket (daemon starts on first use)..."
sudo systemctl enable --now docker.socket

# Membership in the docker group is root-equivalent on this machine — that is
# the trade-off for running docker without sudo.
if id -nG "$USER" | tr ' ' '\n' | grep -qx docker; then
  echo "$USER is already in the docker group."
else
  echo "Adding $USER to the docker group..."
  sudo usermod -aG docker "$USER"
fi

cat <<EOF

Docker is installed:

  $(docker --version)
  $(docker compose version)
  $(docker buildx version)

Re-login (or run 'newgrp docker' in a terminal) so the docker group takes
effect, then verify with:

  docker run --rm hello-world

Firewall note: ufw does NOT filter ports published with -p. 'docker run -p
8080:80' is reachable from the LAN even if ufw would block 8080. For dev
services, bind to localhost instead:

  docker run -p 127.0.0.1:8080:80 ...
  # compose:  ports: ["127.0.0.1:8080:80"]

To start the daemon at boot (e.g. for containers with --restart policies):

  sudo systemctl enable docker.service

To uninstall: sudo systemctl disable --now docker.socket docker.service
              sudo pacman -Rns docker docker-compose docker-buildx
              sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker
              sudo gpasswd -d $USER docker

EOF
