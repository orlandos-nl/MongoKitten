# ``Meow``

Object Document Mapper for MongoDB

## Overview

The Meow Framework provides type-checked APIs for all common operations when working with MongoDB. 

Meow makes use of a protocol called ``Model``, which you need to adopt onto any database models. Models simply need to conform to Codable, and provide a stored property named `_id` containing an instance's unique identifier.

You can access the CRUD APIs through ``MeowCollection``, a type-checked alternative to MongoKitten's `MongoCollection`.

The Meow documentation assumes familiarity with MongoKitten, and you must at least have connected to MongoDB through MongoKitten.
