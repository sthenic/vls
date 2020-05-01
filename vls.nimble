# Package
version = "0.1.0"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 language server written in Nim."
license = "MIT"
src_dir = "src"
bin = @["vls"]

# Dependencies
requires "nim >= 1.2.0"
requires "vparse >= 0.1.0"


task test, "Run the test suite":
   exec("nimble protocoltests")


task protocoltests, "Run the protocol test suite":
   with_dir("tests"):
      exec("nim c --hints:off -r trecv")
