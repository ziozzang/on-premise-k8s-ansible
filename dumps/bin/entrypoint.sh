#!/bin/bash

find /files/bin/ | grep -v entrypoint.sh | grep '.sh$' | xargs -I X bash X

