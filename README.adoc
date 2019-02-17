
=== Nim LMDB

image:https://img.shields.io/badge/status-alpha-orange.svg[badge]
image:https://img.shields.io/github/tag/FedericoCeratto/nim-lmdb.svg[tags]
image:https://img.shields.io/badge/License-OpenLDAP-blue.svg[License]
image:https://circleci.com/gh/FedericoCeratto/nim-lmdb.svg?style=svg["CircleCI", link="https://circleci.com/gh/FedericoCeratto/nim-lmdb"]

Nim wrapper for the https://symas.com/lmdb/[Symas LMDB] library

"...with only 32KB of object code, LMDB may seem tiny. But it’s the right 32KB."
 - from the LMDB home page.

More documentation: http://www.lmdb.tech/doc/[upstream docs] - https://en.wikipedia.org/wiki/Lightning_Memory-Mapped_Database[wikipedia page] - https://caolan.org/posts/exploring_lmdb.html[exploring LMDB]

### Features

* Lightweight and ultra fast
* nim doc documentation
* Basic functional tests and benchmarks
* Tested on Linux

### Usage

[source,bash]
----
# Development library:
nimble install lmdb

# Runtime dependency:
sudo apt-get install liblmdb0
----

[source,nim]
----
import lmdb

# create dbenv, transaction and a dbi
let dbenv = newLMDBEnv("./testdb")
let txn = dbenv.newTxn()
let dbi = txn.dbiOpen(nil, 0)

txn.put(dbi, "foo", "value")
let g = txn.get(dbi, "foo")
txn.del(dbi, "foo", "value")

# commit or abort transaction
txn.commit() # or txn.abort()

# close dbi and env
dbenv.close(dbi)
dbenv.envClose()
----

Also see tests/functional.nim for more examples.

### Contributing

Testing and PRs are welcome.
