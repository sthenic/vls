# Package
version = "0.3.1"
author = "Marcus Eriksson"
description = "A Verilog IEEE 1364-2005 language server written in Nim."
license = "MIT"
src_dir = "src"
bin = @["vls"]

# Dependencies
requires "nim >= 1.4.0"
requires "vparse >= 0.3.1"
requires "vltoml >= 0.2.0"
requires "vlint >= 0.1.0"


task dbuild, "build with tracing":
   exec("nimble build -d:logdebug")


task orcbuild, "build with ORC":
   exec("nimble build --gc:orc")


task dorcbuild, "build with ORC and tracing":
   exec("nimble build -d:logdebug --gc:orc")


task dinstall, "install":
   exec("nimble install --passNim:-d:logdebug")


task orcinstall, "build with ORC and install":
   exec("nimble install --passNim:--gc:orc --passNim:-d:danger")


task dorcinstall, "build with ORC and tracing and install":
   exec("nimble install --passNim:--gc:orc --passNim:-d:danger --passNim:-d:logdebug")


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
      exec("nim c --hints:off -r tdiagnostics")
      exec("nim c --hints:off -r tdeclaration")
      exec("nim c --hints:off -r treferences")
      exec("nim c --hints:off -r tcompletion")
      exec("nim c --hints:off -r tdocument_symbol")
      exec("nim c --hints:off -r trename")
      exec("nim c --hints:off -r tdocument_highlight")
      exec("nim c --hints:off -r thover")
      exec("nim c --hints:off -r tsignature_help")
