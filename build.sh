#!/usr/bin/env bash
docker build --pull --tag nginx-custom . | tee tmp/build.log
