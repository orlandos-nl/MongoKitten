#!/bin/bash

mongoimport --db=mongokitten-unittest --collection=zips --drop zips.json
