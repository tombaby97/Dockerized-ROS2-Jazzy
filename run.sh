#!/bin/bash

docker rm -f jazzy_container || true
xhost +local:

docker run -it \
  --privileged \
  --net=host \
  --name="jazzy_container" \
  --expose=9091 -p 9091:9091 \
  --env="DISPLAY=$DISPLAY" \
  --env="QT_X11_NO_MITSHM=1" \
  --volume="/dev:/dev" \
  --volume="/tmp/.X11-unix:/tmp/.X11-unix:rw" \
  --volume="$PWD/workspace/:/root/ros2_ws/" \
  --volume="$PWD/.ros/log/:/root/.ros/log/" \
  --volume="/dev/input:/dev/input" \
  --volume="/etc/timezone:/etc/timezone:ro" \
  --volume="/etc/localtime:/etc/localtime:ro" \
  --env=NVIDIA_VISIBLE_DEVICES=all \
  --env=NVIDIA_DRIVER_CAPABILITIES=all \
  jazzy-image \
  bash
  
