#!/usr/bin/env bash
docker build --tag nginx-custom . | tee tmp/build.log
