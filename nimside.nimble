# Package

version = "0.1.0"
author = "The seaqt authors"
description = "Nim Qt/QML integration"
license = "MIT"
srcDir = "src"

# Dependencies

requires "nim >= 2.2.8", "https://github.com/seaqt/nim-seaqt.git#qt-6.4", "unittest2"

task test, "run tests":
  exec "nim r --hints:off tests/test_all"
  exec "make -C examples/plugins"
  exec "nim c examples/minimal/hello"
