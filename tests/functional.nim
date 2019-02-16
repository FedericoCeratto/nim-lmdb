
import unittest, os, times, strutils
from sequtils import toSeq

import lmdb

template bench(cycles: int, name: string, body: untyped) =
  let t0 = epochTime()
  for cnt in 1..cycles:
    body
  let delta = epochTime() - t0
  echo "         $# $# per second" % [$int(cycles.float / delta), name]

proc flush_database_dir() =
  createDir "testdb"
  discard tryRemoveFile "testdb/lock.mdb"
  discard tryRemoveFile "testdb/data.mdb"


suite "lmdb functest":
  flush_database_dir()
  let dbenv = newLMDBEnv("./testdb")

  test "transaction: abort":
    let txn = dbenv.newTxn()
    txn.abort()

  test "transaction: commit empty":
    let txn = dbenv.newTxn()
    txn.commit()

    #txn.renew()

  #test "transaction, dbi - named":
  #  let txn = dbenv.newTxn()
  #  let dbi = txn.dbiOpen("foo", 0)

  #  dbenv.close(dbi)
  #  txn.abort()

  test "transaction, dbi":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)

    dbenv.close(dbi)
    txn.abort()

  test "get":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    expect Exception:
      let g = txn.get(dbi, "foo")
    dbenv.close(dbi)
    txn.abort()

  test "put, get, put, get":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)

    txn.put(dbi, "foo", "nyan")
    check txn.get(dbi, "foo") == "nyan"

    txn.put(dbi, "foo", "nyan2")
    check txn.get(dbi, "foo") == "nyan2"

    dbenv.close(dbi)
    txn.abort()

  test "cursor":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    txn.put(dbi, "foo", "myval2")

    let c = txn.cursorOpen(dbi)
    let s = c.get("foo")
    check s == "myval2"
    expect Exception:
      # DUPSORT required
      check c.count() == 1

    dbenv.close(dbi)
    txn.abort()

  test "cursor2":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    txn.put(dbi, "foo", "myval1")

    let c = txn.cursorOpen(dbi)
    check c.get("foo") == "myval1"
    expect Exception:
      discard c.get("foo", op = NEXT)

    block:
      txn.put(dbi, "foo", "myval2", APPENDDUP)
      txn.put(dbi, "foo", "myval3", APPENDDUP)
      block:
        let c = txn.cursorOpen(dbi)
        check c.get("foo", op = FIRST) == "myval3"
      block:
        let c = txn.cursorOpen(dbi)
        check c.get("foo", op = NEXT) == "myval3"

    dbenv.close(dbi)
    txn.abort()

  test "benchput":
    const cycles = 4
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)

    block:
      bench(cycles, "put() * 4000"):
        for cnt in 0..4000:
          txn.put(dbi, "bench" & $cnt, "val")

    txn.abort()
    dbenv.close(dbi)

  test "bench":
    const cycles = 1_000_000
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)

    txn.put(dbi, "bench", "nyan")

    block get:
      bench(cycles, "get()"):
        discard txn.get(dbi, "bench")

    block put:
      bench(cycles, "put()"):
        txn.put(dbi, "bench", "val")

    txn.abort()
    dbenv.close(dbi)

  test "bench2":
    const cycles = 100_000
    bench(cycles, "open + commit"):
      let txn = dbenv.newTxn()
      txn.commit()

  test "bench3":
    const cycles = 100_000
    bench(cycles, "open + dbiOpen + commit"):
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      dbenv.close(dbi)
      txn.commit()

  test "bench4":
    const cycles = 100_000
    block put:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      txn.put(dbi, "bench", "val")
      txn.commit()

    bench(cycles, "open + dbiOpen + get + commit"):
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      discard txn.get(dbi, "bench")
      dbenv.close(dbi)
      txn.commit()

    block del:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      txn.del(dbi, "bench", "val")
      txn.commit()

  test "put, commit, get":
    block put:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      txn.put(dbi, "foo", "nyan")
      dbenv.close(dbi)
      txn.commit()

    block get:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      let g = txn.get(dbi, "foo")
      check g == "nyan"
      dbenv.close(dbi)
      txn.commit()

    block put:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      txn.put(dbi, "foo", "nyan2")
      dbenv.close(dbi)
      txn.commit()

    block get:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      let g = txn.get(dbi, "foo")
      check g == "nyan2"
      dbenv.close(dbi)
      txn.commit()

  test "stat":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    let stat = txn.stat(dbi)
    check stat.msEntries == 1
    dbenv.close(dbi)
    txn.abort()

  test "invalid put":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    expect Exception:
      txn.put(dbi, "", "nyan2")
    dbenv.close(dbi)
    txn.commit()

  test "del":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    txn.put(dbi, "deltest", "deleteme")
    txn.del(dbi, "deltest", "deleteme")
    expect Exception:
      txn.del(dbi, "deltest", "deleteme")
    dbenv.close(dbi)
    txn.abort()

  test "emptyDb deleteAndCloseDb":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    txn.emptyDb(dbi)
    txn.deleteAndCloseDb(dbi)
    dbenv.close(dbi)
    txn.abort()

  test "scan_from":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)

    txn.emptyDb(dbi)
    txn.put(dbi, "key a1", "a1 should not appear")
    txn.put(dbi, "key z1", "z1")
    txn.put(dbi, "key foo2", "foo2")
    txn.put(dbi, "key foo", "foo")
    txn.put(dbi, "key a2", "a2 should not appear")
    txn.put(dbi, "key z2", "z2")

    let c = txn.cursorOpen(dbi)
    let found = toSeq c.scan_from("key foo")
    check found == @["foo", "foo2", "z1", "z2"]
    close c

    dbenv.close(dbi)
    txn.abort()

  #[
  FIXME
  test "cursor":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    let cur = txn.cursorOpen(dbi)
    txn.put(dbi, "foo_c", "nyan")
    check txn.get(dbi, "foo_c") == "nyan"
    # WTF
    check cur.get("foo_c") == "nyan"
    cur.cursorClose()
    dbenv.close(dbi)
    txn.abort()

  test "DUPSORT, transaction, cursor, count":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", DUPSORT)
    let cur = txn.cursorOpen(dbi)
    txn.put(dbi, "foo", "nyan")
    check txn.get(dbi, "foo") == "nyan"
    check getFlags(txn, dbi) == DUPSORT
    echo 111
    echo cur.count()
    echo 111
    cur.cursorClose()
    dbenv.close(dbi)
    txn.abort()
  ]#

  test "transaction, cursor":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    #echo count()
    dbenv.close(dbi)
    txn.abort()

  dbenv.envClose()


suite "dupsort":

  flush_database_dir()
  let dbenv = newLMDBEnv("./testdb")

  test "dupsort":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", CREATE or DUPSORT)
    let cur = txn.cursorOpen(dbi)
    check getFlags(txn, dbi) == DUPSORT
    txn.put(dbi, "foo", "myval 1")
    check txn.get(dbi, "foo") == "myval 1"
    # echo cur.count()
    close cur

    let c = txn.cursorOpen(dbi)
    check c.get("foo") == "myval 1"
    expect Exception:
      discard c.get("foo", op = NEXT)

    block:
      txn.put(dbi, "foo", "myval 2", APPENDDUP)
      txn.put(dbi, "foo", "myval 3", APPENDDUP)
      block:
        let c = txn.cursorOpen(dbi)
        check c.get("foo", op = FIRST) == "myval 1"
      block:
        let c = txn.cursorOpen(dbi)
        check c.get("foo") == "myval 1"
        check c.get("foo", op = NEXT) == "myval 2"
        check c.get("foo", op = NEXT) == "myval 3"
      block:
        let c = txn.cursorOpen(dbi)
        check c.get("foo", op = NEXT) == "myval 1"
        check c.get("foo", op = NEXT) == "myval 2"
        check c.get("foo", op = NEXT) == "myval 3"

      test "iterator":
        let c = txn.cursorOpen(dbi)
        var cnt = 0
        for i in c.get("foo"):
          cnt.inc
        check cnt == 3
        close c

    txn.abort()

  test "dupsort":
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", CREATE or DUPSORT)
    check getFlags(txn, dbi) == DUPSORT

    test "iterator: nonexistent":
      let c = txn.cursorOpen(dbi)
      var cnt = 0
      for i in c.get("nonexistent"):
        cnt.inc
      check cnt == 0
      close c

    test "q":
      txn.put(dbi, "foo", "myval 1")

    test "iterator: nonexistent":
      let c = txn.cursorOpen(dbi)
      var cnt = 0
      for i in c.get("nonexistent"):
        cnt.inc
      check cnt == 1 # FIXME ?!
      close c

    txn.abort()

  dbenv.envClose()


suite "multi":

  test "open nil, maxdbs = 1":
    flush_database_dir()
    let dbenv = newLMDBEnv("./testdb", maxdbs=1)
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", CREATE)
    txn.abort()
    dbenv.envClose()

  test "open named db while maxdbs = 0":
    flush_database_dir()
    let dbenv = newLMDBEnv("./testdb", maxdbs=0)
    let txn = dbenv.newTxn()
    expect Exception:
      let dbi = txn.dbiOpen("foo", CREATE)
    txn.abort()
    dbenv.envClose()

  test "open named db":
    flush_database_dir()
    let dbenv = newLMDBEnv("./testdb", maxdbs=1)
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("foo", CREATE)
    expect Exception:
      let dbi2 = txn.dbiOpen("bar", CREATE)
    dbenv.close(dbi)
    txn.abort()
    dbenv.envClose()

echo "done"
