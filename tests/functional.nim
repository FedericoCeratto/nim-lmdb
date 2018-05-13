
import unittest, os, times, strutils

import lmdb

template bench(cycles: int, name: string, body: untyped) =
  let t0 = epochTime()
  for cnt in 0..cycles:
    body
  let delta = epochTime() - t0
  echo "    $# $# per second" % [$int(cycles.float / delta), name]


suite "functest":

  createDir "testdb"
  discard tryRemoveFile "testdb/lock.mdb"
  discard tryRemoveFile "testdb/data.mdb"

  let dbenv = newLMDBEnv("./testdb")

  test "transaction: abort":
    let txn = dbenv.newTxn()
    txn.abort()

  test "transaction: commit empty":
    let txn = dbenv.newTxn()
    txn.commit()

    #txn.renew()

  test "transaction, dbi":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)

    dbenv.close(dbi)
    txn.abort()

  test "get":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)
    expect Exception:
      let g = txn.get(dbi, "foo")
    dbenv.close(dbi)
    txn.abort()

  test "put, get, put, get":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)

    txn.put(dbi, "foo", "nyan")
    check txn.get(dbi, "foo") == "nyan"

    txn.put(dbi, "foo", "nyan2")
    check txn.get(dbi, "foo") == "nyan2"

    dbenv.close(dbi)
    txn.abort()

  #test "cursor":
  #  let txn = dbenv.newTxn()
  #  let dbi = txn.dbiOpen(nil, 0)

  #  let c = txn.cursorOpen(dbi)
  #  check c.count() == 2

  #  dbenv.close(dbi)
  #  txn.abort()

  test "bench":
    const cycles = 1_000_000
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)

    txn.put(dbi, "bench", "nyan")

    block get:
      bench(cycles, "get()"):
        discard txn.get(dbi, "bench")

    block put:
      bench(cycles, "put()"):
        txn.put(dbi, "bench", "val")

    dbenv.close(dbi)
    txn.commit()

  test "bench":
    const cycles = 100_000
    bench(cycles, "open + commit"):
      let txn = dbenv.newTxn()
      txn.commit()

  test "bench":
    const cycles = 100_000
    bench(cycles, "open + dbiOpen + commit"):
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen(nil, 0)
      dbenv.close(dbi)
      txn.commit()

  test "bench":
    const cycles = 100_000
    bench(cycles, "open + dbiOpen + get + commit"):
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen(nil, 0)
      discard txn.get(dbi, "bench")
      dbenv.close(dbi)
      txn.commit()

  test "put, commit, get":
    block put:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen(nil, 0)
      txn.put(dbi, "foo", "nyan")
      dbenv.close(dbi)
      txn.commit()

    block get:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen(nil, 0)
      let g = txn.get(dbi, "foo")
      check g == "nyan"
      dbenv.close(dbi)
      txn.commit()

    block put:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen(nil, 0)
      txn.put(dbi, "foo", "nyan2")
      dbenv.close(dbi)
      txn.commit()

    block get:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen(nil, 0)
      let g = txn.get(dbi, "foo")
      check g == "nyan2"
      dbenv.close(dbi)
      txn.commit()

  test "invalid put":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)
    expect Exception:
      txn.put(dbi, "", "nyan2")
    dbenv.close(dbi)
    txn.commit()

  test "del":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)
    txn.put(dbi, "deltest", "deleteme")
    txn.del(dbi, "deltest", "deleteme")
    expect Exception:
      txn.del(dbi, "deltest", "deleteme")
    dbenv.close(dbi)
    txn.abort()

  test "stat":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)
    let stat = txn.stat(dbi)
    check stat.msEntries == 2
    dbenv.close(dbi)
    txn.abort()

  test "emptyDb deleteAndCloseDb":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)
    txn.emptyDb(dbi)
    txn.deleteAndCloseDb(dbi)
    dbenv.close(dbi)
    txn.abort()

  test "transaction, cursor":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen(nil, 0)
    let cur = txn.cursorOpen(dbi)
    #echo cur.count()
    cur.cursorClose()
    dbenv.close(dbi)
    txn.abort()

  dbenv.envClose()

echo "done"
