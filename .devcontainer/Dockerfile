FROM ubuntu:noble AS devenv

# Install Packages
RUN apt update
RUN apt upgrade -y

RUN apt install -y sudo zsh nano curl wget git
RUN git config --system --add safe.directory '*'
RUN apt install -y iputils-ping
RUN apt install -y postgresql-client
RUN apt install -y docker.io docker-compose-v2
ENV SHELL=zsh

# Configure Locales
RUN apt-get update && apt-get install -y locales locales-all
ENV LC_ALL=en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US.UTF-8

# Run as the image's built-in non-root user (UID 1000, remapped to the host
# UID by the devcontainer CLI) so files written to the bind-mounted repo stay
# owned by the host user instead of root.
RUN echo 'ubuntu ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/ubuntu && chmod 0440 /etc/sudoers.d/ubuntu
RUN chsh -s "$(which zsh)" ubuntu

USER ubuntu
WORKDIR /home/ubuntu

# Pre-create volume mount points so fresh named volumes inherit this ownership
RUN mkdir -p .local/share/mise .m2

# Configure ZSH
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN sed -i 's/robbyrussell/flower-dance/g' .zshrc
RUN curl -o ~/.oh-my-zsh/themes/flower-dance.zsh-theme https://raw.githubusercontent.com/MarcyLeite/flower-dance-omzsh/main/flower-dance.zsh-theme

# Add mise (installs Node/Python/Java per repo-root default, and Python/
# Java/uv per-module on top of that — versions read from each module's own
# manifest, see .mise.toml at the repo root and in akpedia-server/akpedia-ml)
RUN curl https://mise.run | sh
ENV PATH="/home/ubuntu/.local/bin:/home/ubuntu/.local/share/mise/shims:${PATH}"
RUN echo 'eval "$(mise activate zsh)"' >> .zshrc

CMD ["/bin/zsh"]