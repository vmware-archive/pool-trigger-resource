#!/bin/bash

set -e

params=$*

docker run --rm -v "$(pwd)":/opt/resource cfmobile/bosh-release /bin/bash -c "/opt/resource/tests/tests.sh $params && echo \"all tests passed\" || echo \"tests failed\""
