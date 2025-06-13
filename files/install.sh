#!/bin/bash

set -eux

# Move to the HOME directory. The install script could have been run from a different
# directory and some install commands like NPM or Go require a clean home directory to work.
cd "$HOME"

# Silence SSH logins.
touch ~/.hushlogin

# Basic global setup.
sudo apt update --allow-releaseinfo-change
sudo apt install -y wget tar curl autoconf jq git build-essential libnss3-tools unzip ca-certificates gnupg
echo 'Acquire::AllowUnsizedPackages true;' | sudo tee /etc/apt/apt.conf.d/50unsized

# Upgrade packages.
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

# Install: Go.
WANTED=1.24.0
function install_go {
  sudo rm -rf /usr/local/go
  wget -q -O /tmp/go.tar.gz "https://dl.google.com/go/go${WANTED}.linux-amd64.tar.gz"
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
}
if ! command -v go &> /dev/null
then
  install_go
fi
VERSION=$(go version | { read _ _ VERSION _; echo "${VERSION#go}"; })
if [ "$VERSION" != $WANTED ]
then
  install_go
fi

# Install: Buf.
WANTED=1.33.0
function install_buf {
  curl -sSL "https://github.com/bufbuild/buf/releases/download/v${WANTED}/buf-Linux-x86_64" -o /tmp/buf
  sudo mv /tmp/buf /usr/local/bin/buf
  chmod +x /usr/local/bin/buf
}
if ! command -v buf &> /dev/null
then
  install_buf
fi
VERSION=$(buf --version)
if [ "$VERSION" != $WANTED ]
then
  install_buf
fi

# Install: Error fix that increases the Linux kernel quota of allowed watchers. They are too low by default on Ubuntu.
# Code extracted from: https://stackoverflow.com/questions/22475849/node-js-what-is-enospc-error-and-how-to-solve
if ! grep "fs.inotify.max_user_watches" /etc/sysctl.conf
then
  echo fs.inotify.max_user_watches=524288 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
  sudo sysctl --system
fi

# Install: Error fix that disables networking on Docker.
# Code extracted from: https://stackoverflow.com/questions/41453263/docker-networking-disabled-warning-ipv4-forwarding-is-disabled-networking-wil
if ! grep "net.ipv4.ip_forward" /etc/sysctl.conf
then
  echo net.ipv4.ip_forward=1 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p
  sudo sysctl --system
fi

# Install: mkcert.
if ! command -v mkcert &> /dev/null
then
  curl -L -o /tmp/mkcert https://github.com/FiloSottile/mkcert/releases/download/v1.4.4/mkcert-v1.4.4-linux-amd64
  sudo mv /tmp/mkcert /usr/local/bin/mkcert
  chmod +x /usr/local/bin/mkcert
fi

function nvm_installed {
  if [ -z "${NVM_DIR-}" ]
  then
    return 1
  else
    return 0
  fi
}

# Install: Node.
if ! nvm_installed
then
  WANTED=22
  function install_node {
    if [ ! -d "/etc/apt/keyrings" ]
    then
      sudo mkdir -p /etc/apt/keyrings
    fi
    curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --yes --dearmor -o /etc/apt/keyrings/nodesource.gpg
    echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$WANTED.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
    sudo apt update
    sudo apt install -y nodejs
  }
  if ! command -v node &> /dev/null
  then
    install_node
  fi
  VERSION=$(node -v | awk -F \. {'print substr($1, 2)'})
  if [ "$VERSION" != $WANTED ]
  then
    install_node
  fi
fi

# Install: NPM global packages.
sudo rm -rf /usr/lib/node_modules/yarn /usr/lib/node_modules/netlify-cli
if ! nvm_installed
then
  # We need to install NPM in a different batch because any update will make
  # the next packages to miss the files npm itself needs because of the update.
  sudo npm install -g npm@latest
  sudo npm install -g yarn@latest
  sudo npm install -g --unsafe-perm=true netlify-cli@latest

  # Install: Cloudflare Wrangler.
  sudo npm install -g wrangler
else
  npm install -g netlify-cli@latest

  npm install -g wrangler
fi

# Install: pnpm
curl -fsSL https://get.pnpm.io/install.sh | sh -

# Prescan GitHub & Gerrit SSH keys to install Go packages.
ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh-keyscan -p 29418 gerrit.altipla.consulting >> ~/.ssh/known_hosts

# Install: Go private packages.
git config --global url."ssh://git@github.com:".insteadOf "https://github.com"
/usr/local/go/bin/go env -w GOPRIVATE=github.com/lavozdealmeria,github.com/altipla-consulting,github.com/altec-informatica,go.buf.build,buf.build,gerrit.altipla.consulting

# Install: Altipla tools.
/usr/local/go/bin/go install github.com/altipla-consulting/gendc@latest
/usr/local/go/bin/go install github.com/altipla-consulting/wave@latest
/usr/local/go/bin/go install github.com/altipla-consulting/reloader@latest
/usr/local/go/bin/go install github.com/altipla-consulting/linter@latest
/usr/local/go/bin/go install github.com/altipla-consulting/ci@latest
/usr/local/go/bin/go install github.com/mattn/goreman@latest
/usr/local/go/bin/go install github.com/stern/stern@latest
curl 'https://packages.altipla.consulting/whisper/install.sh' | bash
if ! command -v gaestage &> /dev/null
then
  curl https://europe-west1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo apt-key add -
  echo 'deb https://europe-west1-apt.pkg.dev/projects/altipla-tools acpublic main' | sudo tee /etc/apt/sources.list.d/acpublic.list
  sudo apt update
  sudo apt install -y tools/acpublic
fi
# Global install for vscode plugin.
sudo cp ~/go/bin/ci /usr/local/bin/ci

# Install: Go tools.
/usr/local/go/bin/go install github.com/hashicorp/hcl/v2/cmd/hclfmt@latest

# Install: Altipla Packages DEB repository.
curl https://europe-west1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo apt-key add -
echo 'deb https://europe-west1-apt.pkg.dev/projects/altipla-packages altipla-apt main' | sudo tee /etc/apt/sources.list.d/altipla-apt.list
sudo apt update

# Install: Preparation for internal CLI tools.
INSTALLED=$(apt -qq list apt-transport-artifact-registry --installed)
if [ -n "$INSTALLED" ]; then
  curl https://europe-west1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo apt-key add -
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
  echo 'deb http://packages.cloud.google.com/apt apt-transport-artifact-registry-stable main' | sudo tee /etc/apt/sources.list.d/artifact-registry.list
  sudo apt update
  sudo apt install -y apt-transport-artifact-registry
fi

# Install: Gcloud
if ! command -v gke-gcloud-auth-plugin &> /dev/null
then
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
  curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
  sudo apt update
  sudo apt install -y google-cloud-sdk kubectl google-cloud-cli-gke-gcloud-auth-plugin
fi
gcloud --quiet auth configure-docker europe-west1-docker.pkg.dev,eu.gcr.io,gcr.io

# Install: Litestream
wget -q -O /tmp/litestream.deb https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.deb
sudo dpkg -i /tmp/litestream.deb
rm /tmp/litestream.deb

# Install: Java 11.
sudo apt install -y openjdk-11-jdk

# Install: AWS CLI v2.
curl 'https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip' -o awscliv2.zip
unzip -q awscliv2.zip
sudo ./aws/install --update
rm -rf awscliv2.zip aws

# Install: Azure CLI.
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
/usr/local/go/bin/go install github.com/Azure/kubelogin@latest

# Install: WSL utils.
if grep -q icrosoft /proc/version
then
  if ! command -v xdg-open &> /dev/null
  then
    sudo add-apt-repository -y ppa:wslutilities/wslu
    sudo apt update
    sudo apt install -y wslu
    sudo ln -s /usr/bin/wslview /usr/local/bin/xdg-open
  fi
fi

# Install: MySQL client.
sudo apt install -y mysql-client

# Install: Autoupdate script.
mkdir -p ~/.config/sergeant
curl -q https://tools.altipla.consulting/sergeant/autoupdate > ~/.config/sergeant/autoupdate.sh
chmod +x ~/.config/sergeant/autoupdate.sh
curl -q https://tools.altipla.consulting/sergeant/release > ~/.config/sergeant/release

# Install: User configuration.
if [ ! -f ~/.config/user-bashrc.sh ]
then
  {
    echo "#!/bin/bash"
    echo
    echo "# Custom scripts and aliases."
    echo
  } > ~/.config/user-bashrc.sh
fi
if command -v zsh &> /dev/null
then
  if [ ! -f ~/.config/user-zshrc.sh ]
  then
    {
      echo "#!/bin/zsh"
      echo
      echo "# Custom scripts and aliases."
      echo
    } > ~/.config/user-zshrc.sh
  fi
fi

# Install: .bashrc/.zshrc aliases and helpers.
{
  echo "#!/bin/bash"
  echo
  echo "# Go."
  echo "export GOROOT=/usr/local/go"
  echo 'export PATH=$PATH:$GOROOT/bin:$HOME/go/bin:$HOME/bin'
  echo
  echo "# Docker Compose."
  echo "export USR_ID=$(id -u)"
  echo "export GRP_ID=$(id -g)"
  echo "alias dc='docker compose'"
  echo "alias dcrun='docker compose run --rm'"
  echo "alias dps='docker ps --format=\"table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}\"'"
  echo
  echo "# Gcloud."
  echo "alias compute='gcloud compute'"
  echo "export KUBE_EDITOR=nano"
  echo "export USE_GKE_GCLOUD_AUTH_PLUGIN=True"
  echo "source <(kubectl completion bash)"
  echo
  echo "# pnpm"
  echo "alias pn='pnpm'"
  echo
  echo "# Disable Docket Desktop ads."
  echo 'export DOCKER_SCAN_SUGGEST=false'
  echo
  echo "# Autoupdate"
  echo "~/.config/sergeant/autoupdate.sh"
  echo
} > ~/.config/machine-bashrc.sh
if ! grep '.config/machine-bashrc.sh' ~/.bashrc
then
  echo 'source ~/.config/machine-bashrc.sh' >> ~/.bashrc
  echo 'source ~/.config/user-bashrc.sh' >> ~/.bashrc
fi

if command -v zsh &> /dev/null
then
  {
    echo "#!/bin/zsh"
    echo
    echo "# Go."
    echo "export GOROOT=/usr/local/go"
    echo 'export PATH=$PATH:$GOROOT/bin:$HOME/go/bin:$HOME/bin'
    echo
    echo "# Docker Compose."
    echo "export USR_ID=$(id -u)"
    echo "export GRP_ID=$(id -g)"
    echo "alias dc='docker compose'"
    echo "alias dcrun='docker compose run --rm'"
    echo "alias dps='docker ps --format=\"table {{.ID}}\t{{.Names}}\t{{.Ports}}\t{{.Status}}\"'"
    echo
    echo "# Gcloud."
    echo "alias compute='gcloud compute'"
    echo "export KUBE_EDITOR=nano"
    echo "export USE_GKE_GCLOUD_AUTH_PLUGIN=True"
    echo "source <(kubectl completion zsh)"
    echo
    echo "# pnpm"
    echo "alias pn='pnpm'"
    echo
    echo "# Disable Docker Desktop ads."
    echo 'export DOCKER_SCAN_SUGGEST=false'
    echo
    echo "# Autoupdate"
    echo "~/.config/sergeant/autoupdate.sh"
    echo
  } > ~/.config/machine-zshrc.sh
  if ! grep '.config/machine-zshrc.sh' ~/.zshrc
  then
    echo 'source ~/.config/machine-zshrc.sh' >> ~/.zshrc
    echo 'source ~/.config/user-zshrc.sh' >> ~/.zshrc
  fi
fi

set +eux
