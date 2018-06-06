#!/bin/bash

# Swift 4.2 is not yet supported by SourceKitten, so we override it to the non-beta toolchain here
export XCODE_DEFAULT_TOOLCHAIN_OVERRIDE="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain"

# Check sourcery version
sourcery_version=$(sourcery --version)
expected_version="0.11.2"

if [[ "$sourcery_version" != "$expected_version" ]]; then
echo "warning: Sourcery version $sourcery_version is installed, but $expected_version was expected"
fi

echo "ℹ️  Generating FutureConvenience"
sourcery --templates SourceryTemplates/FutureConvenience.stencil --output Sources/MongoKitten/FutureConvenience.swift --sources Sources/MongoKitten
