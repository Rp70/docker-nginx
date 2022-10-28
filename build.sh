#!/usr/bin/env bash

set -ex

docker build --pull --tag rp70/nginx . | tee tmp/build.log
