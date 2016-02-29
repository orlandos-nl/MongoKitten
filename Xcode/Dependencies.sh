#!/bin/bash

#  Dependencies.sh
#  Constructor
#
#  Created by Robbert Brandsma on 29-02-16.
#  Copyright © 2016 PlanTeam. All rights reserved.

cd "$SRCROOT/.."

if [[ $ACTION == "clean" ]]; then
    echo "Cleaning built products"
    swift build --clean build
    exit $?
fi

if [ Package.swift -nt Packages ]; then
    echo "Dependencies will be fetched again because Package.swift is newer than the Packages folder."
    swift build --clean dist
fi

if [ -a ".build/debug/KituraRouter.a" ]; then
# Nothing to do
    echo "Dependencies already present. Not rebuilding."
    exit 0
fi

# Run make and exit with that status
swift build 2>&1 | sed -l "s/: warning:/info: foutjebedankt:/"
exit $?