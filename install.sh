#!/usr/bin/env bash

# Detect if not Debian-like
[[ ! "$(uname -a)" =~ "Ubuntu" ]] && [[ ! "$(uname -a)" =~ "Debian" ]] && echo "This installation is intended for Ubuntu and (maybe) Debian. You don't appear to have either. This script will exit." && exit

# Check for required utilities
[ ! -x "$(command -v curl)" ] && echo "curl is required to install. Please install before proceeding." && exit
[ ! -x "$(command -v wget)" ] && echo "wget is required to install. Please install before proceeding." && exit
[ ! -x "$(command -v git)" ] && echo "git is required to install. Please install before proceeding." && exit
[ ! -x "$(command -v python)" ] && echo "python is required to install. Please install before proceeding." && exit

# Install Docker
if [ ! -x "$(command -v docker)" ]; then
  echo "Docker seems to be installed already. Skipping installation"
else
  echo "Installing Docker"
  # See: https://get.docker.com
  /bin/bash -c "$(curl -fsSL https://get.docker.com)"
fi

# Install Docker Compose
if [ ! -x "$(command -v docker-compose)" ]; then
  echo "Docker Compose seems to be installed already. Skipping installation"
else
  echo "Installing Docker Compose"
  # See: https://docs.docker.com/compose/install/
  sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# Clone repo
echo "Downloading Aerogel config files"
$WORKDIR=$HOME/aerogel
if [ ! -d "$WORKDIR" ]; then
  git clone --recursive https://github.com/au5ton/aerogel.git $WORKDIR
else
  echo "Aerogel repository already downloaded, pulling latest version"
  git -C $WORKDIR pull origin master
fi


# Prepare default configs
echo "Opening config files for server"
cp $WORKDIR/minecraft.env.example $WORKDIR/minecraft.env
cp $WORKDIR/parrot.env.example $WORKDIR/parrot.env

# Prompt user to update configs
select-editor
editor $WORKDIR/minecraft.env
editor $WORKDIR/parrot.env

# Create the container mountpoint
echo "Creating plugins folder"
sudo mkdir -p /mnt/minecraft/plugins

# Downloading plugins
PLUGINS=$WORKDIR/plugins/*
for f in $PLUGINS
do
  echo "Downloading plugin $f ..."
  URL=$(cat $f)
  wget "$f" -q --show-progress -P /mnt/minecraft/plugins
  cat $f
done

# Start the containers
echo "Starting containers"
docker-compose --project-directory $WORKDIR up -d

# Setting permissions for job script
echo "Setting permissions for autoshutdown.sh"
sudo chmod +x $WORKDIR/autoshutdown.sh

echo "Appending job to crontab"
# Get current crontab
sudo crontab -l > $WORKDIR/.mytab
# Append to copy
echo "*/5 * * * * $WORKDIR/autoshutdown.sh" >> $WORKDIR/.mytab
# Install new crontab
sudo crontab $WORKDIR/.mytab
# Delete temporary copy
rm $WORKDIR/.mytab

echo "Setup is complete"


