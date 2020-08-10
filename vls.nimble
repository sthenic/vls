# Package
version = "0.1.0"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 language server written in Nim."
license = "MIT"
src_dir = "src"
bin = @["vls"]

# Dependencies
requires "nim >= 1.2.6"
requires "vparse >= 0.1.1"
requires "vltoml >= 0.1.0"


task dbuild, "install":
   exec("nimble build -d:logdebug")


task dinstall, "install":
   exec("nimble install --passNim:-d:logdebug")


task test, "Run the test suite":
   exec("nimble protocoltests")
   exec("nimble featuretests")


task protocoltests, "Run the protocol test suite":
   with_dir("tests/protocol"):
      exec("nim c --hints:off -r trecv")
      exec("nim c --hints:off -r tsend")


task featuretests, "Run the language feature test suite":
   with_dir("tests/features"):
      exec("nim c --hints:off -r tsyntax")
      exec("nim c --hints:off -r tdeclaration")
      exec("nim c --hints:off -r treferences")
      exec("nim c --hints:off -r tcompletion")
      exec("nim c --hints:off -r tdocument_symbol")
      exec("nim c --hints:off -r trename")
      exec("nim c --hints:off -r tdocument_highlight")
      exec("nim c --hints:off -r thover")
      exec("nim c --hints:off -r tsignature_help")
