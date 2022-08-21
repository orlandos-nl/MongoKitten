#!/bin/sh
sleep 5
mongo --host mongo-1:27017 <<EOF
   var cfg = {
        "_id": "rs0",
        "version": 1,
        "members": [
            {
                "_id": 0,
                "host": "mongo-1:27017",
                "priority": 2
            },
            {
                "_id": 1,
                "host": "mongo-2:27017",
                "priority": 1
            },
            {
                "_id": 2,
                "host": "mongo-3:27017",
                "priority": 0,
                "arbiterOnly": true
            }
        ]
    };
    rs.initiate(cfg, { force: true });
    rs.reconfig(cfg, { force: true });
    rs.status();
EOF