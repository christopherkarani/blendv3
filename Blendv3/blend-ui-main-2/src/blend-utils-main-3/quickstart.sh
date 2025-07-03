#!/bin/bash

set -e

case "$1" in
local)
    echo "Using standalone network"
    ARGS="--local --testnet"
    ;;
futurenet)
    echo "Using Futurenet network"
    ARGS="--futurenet"
    ;;
*)
    echo "Usage: $0 local|futurenet"
    exit 1
    ;;
esac

shift

# Run the soroban-preview container
# Remember to do:
# make build-docker

echo "Creating docker soroban network"
(docker network inspect soroban-network -f '{{.Id}}' 2>/dev/null) \
  || docker network create soroban-network

echo "Searching for a previous soroban-protocol docker container"
containerID=$(docker ps --filter="name=soroban-protocol" --all --quiet)
if [[ ${containerID} ]]; then
    echo "Start removing soroban-protocol container."
    docker rm --force soroban-protocol
    echo "Finished removing soroban-protocol container."
else
    echo "No previous soroban-protocol container was found"
fi

currentDir=$(pwd)
docker run -dti \
  --volume ${currentDir}:/workspace \
  --name soroban-protocol \
  -p 8001:8000 \
  --ipc=host \
  --network soroban-network \
  soroban-protocol:20

# Run the stellar quickstart image

docker run --rm -ti \
  --name stellar \
  --network soroban-network \
  -p 8000:8000 \
  stellar/quickstart:testing \
  $ARGS \
  --enable-soroban-rpc \
  "$@" # Pass through args from the CLI