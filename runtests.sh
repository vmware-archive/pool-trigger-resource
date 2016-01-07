#!/bin/sh

set -e 

## run tests
docker run -v ~/workspace/pool-trigger-resource/tests:/opt/resource-tests triggers /opt/resource-tests/check.sh