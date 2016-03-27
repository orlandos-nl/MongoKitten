#!/bin/bash

cd "$SRCROOT/.."

if [[ $ACTION == "clean" ]]; then
    echo "Cleaning built products"
    rm .build/debug/.dependencies-ready &>/dev/null
    swift build --clean build
    exit $?
fi

if [ Package.swift -nt Packages ]; then
    echo "Dependencies will be fetched again because Package.swift is newer than the Packages folder."
    swift build --clean dist
fi

if [ -a ".build/debug/.dependencies-ready" ]; then
    # Nothing to do
    echo "Dependencies already present. Not rebuilding."
else
    # Run swift build
    swift build 2>&1 | sed -l -e "s/: warning:/info: a dependency is complaining:/"
    if [[ $? != 0 ]]; then
        exit $?
    fi
fi



# Generate the config file

linkerflags="\$(inherited)"

files=$(find .build -name '*.o')

for f in $files; do
  mname=$(basename $(dirname $f) .build)
  if [[ $mname == $PROJECT_NAME ]]; then
    continue
  fi
  linkerflags+=" \$(SRCROOT)/../$f"
done

echo "Linker flags: $linkerflags"

cat > "$SRCROOT/SPM.xcconfig" <<EOF
LIBRARY_SEARCH_PATHS = \$(inherited) \$(SRCROOT)/../.build/debug
SWIFT_INCLUDE_PATHS = \$(inherited) \$(SRCROOT)/../.build/debug \$(SRCROOT)/../Packages/**
OTHER_LDFLAGS = \$(inherited) -L\$(SRCROOT)/../.build/debug $linkerflags
LD_LIBRARY_PATH = \$(inherited) \$(SRCROOT)/../.build/debug
EOF

touch .build/debug/.dependencies-ready
