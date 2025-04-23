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

#Install from a requirements.txt file (recommended for larger projects)
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

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

# Install each package in a separate RUN command 
RUN apt-get install -y --no-install-recommends ros-jazzy-rviz2
RUN apt-get install -y --no-install-recommends ros-jazzy-nav2*
RUN apt-get install -y --no-install-recommends ros-jazzy-rqt*
RUN apt-get install -y --no-install-recommends vim
RUN apt-get install -y --no-install-recommends net-tools
RUN apt-get install -y --no-install-recommends ros-jazzy-rmw-cyclonedds-cpp

# Add additional if required , similarily like the above commands.



#Install Librealsense

ARG LIBREALSENSE_SOURCE_VERSION=v2.55.1
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

#Install librealsense2
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    git \
    cmake \
    build-essential \
    libssl-dev \
    pkg-config \
    libusb-1.0-0-dev \
    libgtk-3-dev \
    libglfw3-dev \
    libgl1-mesa-dev \
    libglu1-mesa-dev && \
    rm -rf /var/lib/apt/lists/*

# Set a working directory
WORKDIR /app/librealsense

# Clone the librealsense repository, specifically the 'development' branch
RUN git clone https://github.com/IntelRealSense/librealsense.git . && \
    git checkout development

# Create a build directory and navigate into it
RUN mkdir build && \
    cd build

# Configure the build with CMake.
# You can add -DCMAKE_BUILD_TYPE=Release for an optimized build
# and other options as needed (e.g., -DBUILD_EXAMPLES=true, -DBUILD_GRAPHICAL_EXAMPLES=true)
RUN cd build && \
    cmake ..

# Build the library
RUN cd build && \
    make -j$(nproc)

# Install the built library and tools
# If you intend to use the built library in subsequent layers or the final image,
# you'll likely want to install it.
RUN cd build && \
    make install

# Clean up build artifacts to reduce image size
# This step should ideally be done after installation if you chose to install.
# If you only need the built files within this layer or a multi-stage build,
# you might skip the 'make install' and adjust the cleanup.
RUN rm -rf /app/librealsense/build
RUN rm -rf /app/librealsense/.git # Remove git history if not needed in the final image

#Install from a requirements.txt file (recommended for larger projects)
COPY requirements.txt /tmp/requirements.txt
RUN pip install -r /tmp/requirements.txt

# Clean up (remove unnecessary files)
RUN apt-get clean && rm -rf /var/lib/apt/lists/*

# Create the ROS 2 workspace directory
RUN mkdir -p /ros2_ws/src

# Copy the contents of workspace/src to ros2_ws/src
COPY workspace/src /ros2_ws/src

# Copy the setup script
COPY setup_ros2_jazzy.sh /

# Make the setup script executable
RUN chmod +x /setup_ros2_jazzy.sh

# Copy commands to bashrc
COPY source_commands.txt /tmp/source_commands.txt
RUN cat /tmp/source_commands.txt >> /root/.bashrc && rm /tmp/source_commands.txt

# Set up entrypoint
ENTRYPOINT ["/setup_ros2_jazzy.sh"]

# Define the volume for the ROS 2 workspace source directory
VOLUME /ros2_ws/src
