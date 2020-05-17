#!/usr/bin/env bash

# Inspired by: https://github.com/trevor-laher/OnDemandMinecraft/blob/master/instancesetup/autoshutdown.sh

# Safely stop the server and shutdown
function server_off()
{
  # make an attempt to safely turn off the server
  curl "http://127.0.0.1:8000/api/cmd/say%20shutting%20down"
  sleep 5s
  curl "http://127.0.0.1:8000/api/cmd/stop"
  sleep 5s
  # actually turn off
  sudo /sbin/shutdown -P +1
}

# Fetch API and get online count
function get_online()
{
  NUM=$(curl --silent http://127.0.0.1:8000/api/slots | python -c "import sys, json; print(json.load(sys.stdin)['online'])");
  [ ! "$?" == "0" ] && echo "Process exited with an error, shutting down as a precaution" && server_off;
  echo "$NUM";
}

# over the period of 15 minutes, check every 5 minutes
for i in {1..3}; do 
  ONLINE=$(get_online);
  [[ ! "$ONLINE" == "0" ]] && echo "Some players are online! No shutdown will take place" && exit;
  [[ "$ONLINE" == "0" ]] && echo "No players are online";
  [[ ! "$i" == "3" ]] && echo "Checking again in 5 minutes" && sleep 10s; # dont sleep on the last iteration
done

echo "15 minutes exceeded"

# the above for loop wasn't broken, so it's time to shutdown
server_off
