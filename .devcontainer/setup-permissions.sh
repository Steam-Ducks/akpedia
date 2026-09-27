#!/usr/bin/env bash
# Runs as onCreateCommand (before postCreateCommand) so the group changes below
# are already in effect for later lifecycle commands and terminals.
set -euo pipefail

# Let the non-root user use the host's docker.sock. Its GID comes from the host
# and differs between machines, so match it at runtime instead of in the image.
sock_gid="$(stat -c '%g' /var/run/docker.sock)"
sock_group="$(getent group "$sock_gid" | cut -d: -f1 || true)"
if [ -z "$sock_group" ]; then
  sock_group=hostdocker
  sudo groupadd -g "$sock_gid" "$sock_group"
fi
sudo usermod -aG "$sock_group" "$(id -un)"

# Volumes created while the container ran as root still hold root-owned files
sudo chown -R "$(id -u):$(id -g)" ~/.local/share/mise ~/.m2

# ...and mise installs/shims made back then are symlinks into /root, which
# mise treats as installed but can't execute. Wipe them so entrypoint.sh
# reinstalls under this user's home.
if find ~/.local/share/mise -type l -lname '/root/*' -print -quit | grep -q .; then
  rm -rf ~/.local/share/mise/installs ~/.local/share/mise/shims
fi
