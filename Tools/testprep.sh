#!/bin/bash

echo "MongoKitten Unit Test Preparation Script"

unamestr=`uname`
if [[ "$unamestr" == 'Darwin' ]]; then
	brew update
	brew install mongodb
fi

mongodbpath="/tmp/mongokitten-unittest-db"
mkdir -p $mongodbpath
mongod --fork --syslog --dbpath $mongodbpath

mongoimport --db=mongokitten-unittest --collection=zips --drop zips.json
