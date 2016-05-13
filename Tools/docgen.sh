#!/bin/bash
if [[ "$(basename $(pwd))" = "Tools" ]]; then
  cd ..
fi

XCODE_XCCONFIG_FILE=Tools/docs.xcconfig jazzy
