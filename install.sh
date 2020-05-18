#!/usr/bin/env bash

# Detect if not Debian-like
[[ ! "$(uname -a)" =~ "Ubuntu" ]] && [[ ! "$(uname -a)" =~ "Debian" ]] && echo "This installation is intended for Ubuntu and (maybe) Debian. You don't appear to have either. This script will exit." && exit

# Check for required utilities
[ ! -x "$(command -v curl)" ] && echo "curl is required to install. Please install before proceeding." && exit
[ ! -x "$(command -v wget)" ] && echo "wget is required to install. Please install before proceeding." && exit
[ ! -x "$(command -v git)" ] && echo "git is required to install. Please install before proceeding." && exit
[ ! -x "$(command -v python)" ] && echo "python is required to install. Please install before proceeding." && exit

# Install Docker
if [ ! "$(which docker)" = "" ]; then
  echo "Docker seems to be installed already. Skipping installation"
else
  echo "Installing Docker"
  # See: https://get.docker.com
  /bin/bash -c "$(curl -fsSL https://get.docker.com)"
fi

# Install Docker Compose
if [ ! "$(which docker-compose)" = "" ]; then
  echo "Docker Compose seems to be installed already. Skipping installation"
else
  echo "Installing Docker Compose"
  # See: https://docs.docker.com/compose/install/
  sudo curl -L "https://github.com/docker/compose/releases/download/1.25.5/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# Installs lazydocker for maintenance
sudo curl https://raw.githubusercontent.com/jesseduffield/lazydocker/master/scripts/install_update_linux.sh | bash

# Clone repo
echo "Downloading Aerogel config files"
WORKDIR=$HOME/aerogel
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
  wget "$URL" -P /mnt/minecraft/plugins
done
echo "\n"

# Start the containers
echo "Starting containers"
sudo docker-compose --file "$WORKDIR/docker-compose.yml" up -d

# Configure the restart policy because docker-compose 3.0+ is retarded and won't let us do it ourselves
sudo docker container update --restart unless-stopped aerogel_minecraft_1
sudo docker container update --restart unless-stopped aerogel_parrot_1

# # Wait for server to create plugins folder
# echo "Waiting for server to generate plugins folder"
# while [ ! -d /mnt/minecraft/plugins ]
# do
# 	echo `date`" plugins not ready yet";
# 	sleep 2;
# done

# # Wait for server to process plugins
# echo "Waiting for server to process plugins folder"
# while [ ! -d /mnt/minecraft/plugins/bStats ]
# do
# 	echo `date`" bStats not ready yet";
# 	sleep 2;
# done

# Restarting server to use plugins
sudo docker container restart aerogel_minecraft_1

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


