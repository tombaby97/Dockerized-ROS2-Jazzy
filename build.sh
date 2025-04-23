#!/bin/bash

docker build .  -t jazzy-image-base
docker build . --file Dockerfile  -t jazzy-image
