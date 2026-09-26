#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

docker compose -f akpedia-server/docker-compose.yml up -d db gotenberg

# Join the db/gotenberg compose network so we can reach them by container
# name (we're a sibling container to them via the mounted docker.sock, not a
# parent/child, so "localhost" doesn't route to them).
db_network="$(docker inspect akpedia-db --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}')"
docker network connect "$db_network" akpedia-devcontainer 2>/dev/null || true

~/.local/bin/mise trust .mise.toml
~/.local/bin/mise trust akpedia-server/.mise.toml
~/.local/bin/mise trust akpedia-ml/.mise.toml

~/.local/bin/mise install
(cd akpedia-server && ~/.local/bin/mise install)
(cd akpedia-ml && ~/.local/bin/mise install)

corepack enable
corepack prepare pnpm@latest --activate

chmod +x .devcontainer/scripts/akpedia .devcontainer/scripts/dev.sh .devcontainer/scripts/branch.sh .devcontainer/scripts/commit.sh .devcontainer/scripts/seed.sh
sudo ln -sf "$(pwd)/.devcontainer/scripts/akpedia" /usr/local/bin/akpedia

completion_line="source \"$(pwd)/.devcontainer/scripts/akpedia-completion.zsh\""
grep -qxF "$completion_line" ~/.zshrc || echo "$completion_line" >> ~/.zshrc
