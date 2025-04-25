# Use Ubuntu 24.04 as base image
FROM ubuntu:24.04

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    gnupg2 \
    lsb-release \
    python3-pip \
    build-essential \
    python3-venv \
    && rm -rf /var/lib/apt/lists/*

# Set up a virtual environment
RUN python3 -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Upgrade pip and install colcon-common-extensions
RUN pip install --upgrade pip
RUN pip install -U colcon-common-extensions

# Install zsh and wget
RUN apt-get update && apt-get install -y \
    zsh \
    wget

# Install zsh in docker
RUN sh -c "$(wget -O- https://github.com/deluan/zsh-in-docker/releases/download/v1.1.1/zsh-in-docker.sh)" -- -t robbyrussell

# Set up the ROS 2 repository
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'

# Install ROS 2 Jazzy packages and rosdep
RUN apt-get update && apt-get install -y ros-jazzy-desktop python3-rosdep && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && rosdep update

# Set environment variables
ENV ROS_DISTRO=jazzy
ENV ROS_ROOT=/opt/ros/$ROS_DISTRO

# Update the package list
RUN apt-get update

#Install Librealsense

ARG LIBREALSENSE_SOURCE_VERSION=v2.56.3
ARG REALSENSE_ROS_GIT_URL=https://github.com/IntelRealSense/realsense-ros.git 
ARG REALSENSE_ROS_VERSION=ros2-master

COPY scripts/build-librealsense.sh /opt/realsense/build-librealsense.sh
COPY scripts/install-realsense-dependencies.sh /opt/realsense/install-realsense-dependencies.sh

RUN chmod +x /opt/realsense/install-realsense-dependencies.sh && \
    /opt/realsense/install-realsense-dependencies.sh; \
    chmod +x /opt/realsense/build-librealsense.sh && /opt/realsense/build-librealsense.sh -n -v ${LIBREALSENSE_SOURCE_VERSION};

# Copy hotplug script for udev rules/hotplug for RealSense
RUN mkdir -p /opt/realsense/
COPY scripts/hotplug-realsense.sh /opt/realsense/hotplug-realsense.sh
COPY udev_rules/99-realsense-libusb-custom.rules /etc/udev/rules.d/99-realsense-libusb-custom.rules

# Set up the ROS 2 repository
RUN curl -s https://raw.githubusercontent.com/ros/rosdistro/master/ros.asc | apt-key add -
RUN sh -c 'echo "deb [arch=$(dpkg --print-architecture)] http://packages.ros.org/ros2/ubuntu $(lsb_release -cs) main" > /etc/apt/sources.list.d/ros2-latest.list'

# Install ROS 2 Jazzy packages and rosdep
RUN apt-get update && apt-get install -y ros-jazzy-desktop python3-rosdep && rm -rf /var/lib/apt/lists/*

# Initialize rosdep
RUN rosdep init && rosdep update

# Set environment variables
ENV ROS_DISTRO=jazzy
ENV ROS_ROOT=/opt/ros/$ROS_DISTRO

# Update the package list
RUN apt-get update

# Install each package in a separate RUN command 
RUN apt-get install -y --no-install-recommends ros-jazzy-rviz2
RUN apt-get install -y --no-install-recommends ros-jazzy-nav2*
RUN apt-get install -y --no-install-recommends ros-jazzy-rqt*
RUN apt-get install -y --no-install-recommends vim
RUN apt-get install -y --no-install-recommends net-tools
RUN apt-get install -y --no-install-recommends ros-jazzy-rmw-cyclonedds-cpp
RUN apt-get install -y --no-install-recommends ros-jazzy-velodyne*

# Add additional if required , similarily like the above commands.

#Install from a requirements.txt file (recommended for larger projects)
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# Clean up (remove unnecessary files)
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Create the ROS 2 workspace directory
RUN mkdir -p /root/ros2_ws/src

# Copy the contents of workspace/src to ros2_ws/src
COPY workspace/src /root/ros2_ws/src

# Copy the setup script
COPY setup_ros2_jazzy.sh /

# Make the setup script executable
RUN chmod +x /setup_ros2_jazzy.sh

# Copy commands to bashrc
COPY source_commands.txt /tmp/source_commands.txt
RUN cat /tmp/source_commands.txt >> /root/.bashrc && rm /tmp/source_commands.txt

#Setup uros and micro_ros package
SHELL ["/bin/bash", "-c"]

RUN mkdir -p /root/uros_ws 

WORKDIR /root/uros_ws 

RUN source /opt/ros/jazzy/setup.bash 
RUN git clone -b jazzy https://github.com/micro-ROS/micro_ros_setup.git src/micro_ros_setup
RUN apt-get update && apt-get install python3-vcstool -y
RUN apt-get update && apt-get install python3-colcon-common-extensions -y
RUN rosdep install --from-paths src --ignore-src -y
RUN source /opt/ros/jazzy/setup.bash 

# Build the workspace - Add checks before colcon build
RUN source /opt/ros/jazzy/setup.bash \
 && source /root/.bashrc \
 && echo "--- Environment check after sourcing ---" \
 && echo "AMENT_PREFIX_PATH is: $AMENT_PREFIX_PATH" \
 && echo "Checking for ament_cmake config file:" \
 && ls /opt/ros/jazzy/share/ament_cmake/cmake/ament_cmakeConfig.cmake || echo "!!! ament_cmake config file NOT found where expected !!!" \
 && echo "Checking if colcon can list ament_cmake:" \
 && colcon list | grep ament_cmake || echo "!!! colcon list did NOT show ament_cmake !!!" \
 && echo "Checking if ros2 pkg prefix can find ament_cmake:" \
 && ros2 pkg prefix ament_cmake || echo "!!! ros2 pkg prefix did NOT find ament_cmake !!!" \
 && echo "--- End environment check ---" \
 && colcon build \
 && source install/setup.bash \
 && ros2 run micro_ros_setup create_agent_ws.sh \
 && ros2 run micro_ros_setup build_agent.sh 

#Colcon building the ros2_workspace
WORKDIR /root/ros2_ws
RUN apt update && rosdep install --from-paths src -y --ignore-src --rosdistro jazzy
RUN source /opt/ros/jazzy/setup.bash && source /root/.bashrc && colcon build
WORKDIR /root/

# Set up entrypoint
ENTRYPOINT ["/setup_ros2_jazzy.sh"]

