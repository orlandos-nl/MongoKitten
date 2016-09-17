#!/bin/bash

echo "MongoKitten Unit Test Preparation Script"

mongoimport --db=mongokitten-unittest --collection=zips --drop zips.json
