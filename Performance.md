# Performance

Currently we're working on testing MongoKitten against all major web languages.
So far we've tested faster against all other tested libraries. You can check it yourself by running [the examples here](https://github.com/OpenKitten/Statistics).

All tests generate 2 groups of 10'000 documents. All groups have the same document with an unique ObjectId.
The tests then bulk insert the two groups of 10'000 documents separately.
Before stopping the test we first find the first and the second group separately using a query.
Finally we remove all documents from the collection.

This all happens over an unsecured connection. This is not an encryption/authentication test.

Authentication shouldn't be enough of a drain to have a big impact on your system and SSL performance is left to Libre/OpenSSL.

## Results

MongoKitten 3.1 is still being optimized but has proven to be as performant as the officially supported MongoDB drivers.
