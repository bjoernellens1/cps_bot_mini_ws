version: "3.9"

services:
  # Base image containing dependencies.
  base:
    image: ghcr.io/bjoernellens1/ros2-base:humble
    build:
      context: .
      dockerfile: docker/Dockerfile
      tags:
        - ghcr.io/bjoernellens1/ros2-base:humble
      args:
        ROS_DISTRO: humble
        UNDERLAY_WS: cps_bot_mini_ws
        OVERLAY_WS: overlay_ws
      target: base
      x-bake:
        platforms:
          - linux/arm64
          - linux/amd64
    # Interactive shell
    stdin_open: true
    tty: true
    # Networking and IPC for ROS 2
    network_mode: host
    ipc: host
    # Needed to display graphical applications
    privileged: true
    environment:
      # Allows graphical programs in the container.
      - DISPLAY=${DISPLAY}
      - QT_X11_NO_MITSHM=1
      - NVIDIA_DRIVER_CAPABILITIES=all
    volumes:
      # Allows graphical programs in the container.
      - /tmp/.X11-unix:/tmp/.X11-unix:rw
      - ${XAUTHORITY:-$HOME/.Xauthority}:/root/.Xauthority

  # Overlay image containing the project specific source code.
  overlay:
    extends: base
    image: ghcr.io/bjoernellens1/cps_bot_mini_ws/bot:overlay
    build:
      context: .
      dockerfile: docker/Dockerfile
      tags:
        - ghcr.io/bjoernellens1/cps_bot_mini_ws/bot:overlay
      target: overlay
      x-bake:
        platforms:
          - linux/arm64
          - linux/amd64
    volumes:
      - .:/repo

  # # Additional dependencies for GUI applications
  # guis:
  #   extends: overlay
  #   image: ghcr.io/bjoernellens1/cps_bot_mini_ws/bot:guis
  #   build:
  #     context: .
  #     dockerfile: docker/Dockerfile
  #     tags:
  #       - ghcr.io/bjoernellens1/cps_bot_mini_ws/bot:guis
  #     target: guis
  #     x-bake:
  #       platforms:
  #         - linux/arm64
  #         - linux/amd64
  #   command: >
  #     /bin/bash

  # # Robot State Publisher
  # robot_state_publisher:
  #   extends: overlay
  #   command: >
  #     ros2 launch cps_loki_bringup rsp.launch.py

  # Controller
  controller:
    extends: overlay 
    command: >
      ros2 launch cps_loki_bringup robot_controller.launch.py
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
      - /dev/ttyACM0:/dev/ttyACM0
    restart: unless-stopped
    
  # teleop
  teleop:
    extends: overlay 
    command: >
      ros2 launch cps_loki_bringup robot_joy_teleop.launch.py
    devices:
      - /dev/input:/dev/input
    restart: unless-stopped

  # lidar
  lidar:
    extends: overlay
    command: >
      ros2 launch cps_loki_bringup robot_lidar.launch.py
    devices:
      - /dev/ttyUSB0:/dev/ttyUSB0
      #- /dev/ttyUSB1:/dev/ttyUSB1
      - /dev/ttyACM0:/dev/ttyACM0

  # mapping
  mapping:
    extends: overlay
    command: >
      ros2 launch cps_loki_bringup robot_mapper.launch.py

  # navigation
  navigation:
    extends: overlay
    #command: >
    #  ros2 launch cbot_mini_bringup robot_navigation.launch.py
    #  map_subscribe_transient_local:=true
    command: >
      ros2 launch nav2_bringup bringup_launch.py slam:=True map:=/repo/map.yaml use_sim_time:=False use_composition:=True params_file:=/overlay_ws/src/cps_loki_bringup/config/nav2_params.yaml
    depends_on:
      - lidar
      - controller
      - teleop

  # # rviz2
  # rviz2:
  #   extends: guis
  #   command: >
  #     rviz2
  #   # Needed to display graphical applications
  #   privileged: true
