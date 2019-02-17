
import os, strutils, threadpool, times, unittest

import lmdb

proc flush_database_dir() =
  createDir "testdb"
  discard tryRemoveFile "testdb/lock.mdb"
  discard tryRemoveFile "testdb/data.mdb"

const sleeptime = 150

suite "multithread functest":
  flush_database_dir()

  proc writer(t: int) =
    let dbenv = newLMDBEnv("./testdb", openflags=WRITEMAP)
    echo "[W $#] start" % $t
    for i in 0..5:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      txn.put(dbi, "cnt", $i)
      echo "[W $#] put $#" % [$t, $i]
      txn.commit()
      sleep sleeptime * 2

    echo "[W $#] done" % $t

  proc reader(t: int) =
    sleep sleeptime
    let dbenv = newLMDBEnv("./testdb", openflags=WRITEMAP)
    echo "[R $#] start" % $t
    for i in 0..3:
      let txn = dbenv.newTxn()
      let dbi = txn.dbiOpen("", 0)
      var v = txn.get(dbi, "cnt").parseInt()
      txn.abort()
      echo "[R $#] $# got $#" % [$t, $i, $v]
      doAssert v == i
      sleep sleeptime * 2

    echo "[R $#] done" % $t


  test "one":
    let dbenv = newLMDBEnv("./testdb", openflags=WRITEMAP)
    let txn = dbenv.newTxn()
    let dbi = txn.dbiOpen("", 0)
    txn.put(dbi, "cnt", "-1")
    txn.commit()

    spawn writer(0)
    for t in 0..5:
      spawn reader(t)

    sync()

  echo "done"
