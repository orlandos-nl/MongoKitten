#!/bin/bash

echo "MongoKitten Unit Test Preparation Script"

mongodbpath="/tmp/mongokitten-unittest-db"
mkdir -p $mongodbpath
mongod --fork --syslog --dbpath $mongodbpath

mongoimport --db=mongokitten-unittest --collection=zips --drop zips.json
