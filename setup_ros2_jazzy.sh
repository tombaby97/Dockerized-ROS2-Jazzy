#!/bin/bash

source /opt/ros/jazzy/setup.bash
source /root/.bashrc  # Source the bashrc
cd /ros2_ws
#rosdep install --from-paths src -y --ignore-src
colcon build
source /ros2_ws/install/setup.bash
exec "$@"
