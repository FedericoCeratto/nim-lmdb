# Package

version       = "0.1.2"
author        = "Federico Ceratto"
description   = "LMDB wrapper"
license       = "OpenLDAP Public license"
skipDirs      = @["tests"]

# Dependencies

requires "nim >= 0.18.0"

task tests_functional, "Functional tests":
  exec "nim c -p:. -d:release -r tests/functional.nim"

