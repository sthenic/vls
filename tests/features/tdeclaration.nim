import terminal
import strformat
import os
import osproc
import json

import ../../src/protocol
import ./bootstrap

var nof_passed = 0
var nof_failed = 0

let path = parent_dir(parent_dir(get_current_dir()))
let vls = start_process(path / "vls", options = {})
let ifs = input_stream(vls)
let ofs = output_stream(vls)

# Iniitalize the server, as if we were an LSP client.
initialize(ifs, ofs)

# Open the file "./src/src2.v", expecting no parsing errors.
const src2_path = "./src/src2.v"
const src2_text = static_read(src2_path)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src2_path),
      "languageId": "verilog",
      "version": 0,
      "text": src2_text
   }
}))
assert len(recv(ofs).parameters["diagnostics"]) == 0

template run_test(title: string, stimuli, reference: LspMessage) =
   send(ifs, stimuli)
   let response = recv(ofs)
   if response == reference:
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                     fgWhite, "Test '",  title, "'")
      inc(nof_passed)
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                     fgWhite, "Test '",  title, "'")
      inc(nof_failed)
      detailed_compare(response, reference)


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: declaration
-----------------------""")


run_test("textDocument/declaration: port",
   new_lsp_request(0, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 20,
         "character": 22
      }
   }),
   new_lsp_response(185, 0, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 4, "character": 15},
         "end" : {"line": 4, "character": 15}
      }
   }])
)


run_test("textDocument/declaration: reg",
   new_lsp_request(1, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 28,
         "character": 17
      }
   }),
   new_lsp_response(185, 1, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 16, "character": 8},
         "end" : {"line": 16, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: reg (assignment)",
   new_lsp_request(2, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 22,
         "character": 22
      }
   }),
   new_lsp_response(185, 2, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 15, "character": 8},
         "end" : {"line": 15, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: reg (array)",
   new_lsp_request(3, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 25,
         "character": 19
      }
   }),
   new_lsp_response(185, 3, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 17, "character": 8},
         "end" : {"line": 17, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: integer",
   new_lsp_request(4, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 25,
         "character": 26
      }
   }),
   new_lsp_response(187, 4, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 18, "character": 12},
         "end" : {"line": 18, "character": 12}
      }
   }])
)

run_test("textDocument/declaration: net (wire)",
   new_lsp_request(5, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 33,
         "character": 16
      }
   }),
   new_lsp_response(185, 5, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 14, "character": 9},
         "end" : {"line": 14, "character": 9}
      }
   }])
)

run_test("textDocument/declaration: task",
   new_lsp_request(6, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 44,
         "character": 15
      }
   }),
   new_lsp_response(185, 6, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 35, "character": 9},
         "end" : {"line": 35, "character": 9}
      }
   }])
)

run_test("textDocument/declaration: function",
   new_lsp_request(7, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 50,
         "character": 28
      }
   }),
   new_lsp_response(187, 7, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 39, "character": 13},
         "end" : {"line": 39, "character": 13}
      }
   }])
)

run_test("textDocument/declaration: genvar",
   new_lsp_request(8, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 60,
         "character": 27
      }
   }),
   new_lsp_response(187, 8, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 53, "character": 11},
         "end" : {"line": 53, "character": 11}
      }
   }])
)

run_test("textDocument/declaration: localparam (1)",
   new_lsp_request(9, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 55,
         "character": 24
      }
   }),
   new_lsp_response(187, 9, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 55, "character": 23},
         "end" : {"line": 55, "character": 23}
      }
   }])
)

run_test("textDocument/declaration: localparam (2)",
   new_lsp_request(9, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 55,
         "character": 34
      }
   }),
   new_lsp_response(187, 9, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 55, "character": 32},
         "end" : {"line": 55, "character": 32}
      }
   }])
)

run_test("textDocument/declaration: parameter",
   new_lsp_request(10, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 58,
         "character": 36
      }
   }),
   new_lsp_response(188, 10, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 56, "character": 20},
         "end" : {"line": 56, "character": 20}
      }
   }])
)

run_test("textDocument/declaration: defparam",
   new_lsp_request(11, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 71,
         "character": 14
      }
   }),
   new_lsp_response(188, 11, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 56, "character": 20},
         "end" : {"line": 56, "character": 20}
      }
   }])
)

run_test("textDocument/declaration: specparam",
   new_lsp_request(12, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 73,
         "character": 15
      }
   }),
   new_lsp_response(188, 12, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 73, "character": 14},
         "end" : {"line": 73, "character": 14}
      }
   }])
)

run_test("textDocument/declaration: event",
   new_lsp_request(13, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 76,
         "character": 16
      }
   }),
   new_lsp_response(188, 13, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 75, "character": 10},
         "end" : {"line": 75, "character": 10}
      }
   }])
)

run_test("textDocument/declaration: event (array)",
   new_lsp_request(14, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 76,
         "character": 41
      }
   }),
   new_lsp_response(188, 14, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 75, "character": 24},
         "end" : {"line": 75, "character": 24}
      }
   }])
)

run_test("textDocument/declaration: module",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 83,
         "character": 9
      }
   }),
   new_lsp_response(184, 15, %*[{
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 0, "character": 7},
         "end" : {"line": 0, "character": 7}
      }
   }])
)

# Open the file "./src/src3.v", expecting no parsing errors.
const src3_path = "./src/src3.v"
const src3_header_path = "./src/src3.vh"
const src3_text = static_read(src3_path)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src3_path),
      "languageId": "verilog",
      "version": 0,
      "text": src3_text
   }
}))
assert len(recv(ofs).parameters["diagnostics"]) == 0

run_test("textDocument/declaration: localparam from include file (overlapping)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 15,
         "character": 12
      }
   }),
   new_lsp_response(187, 15, %*[{
      "uri": "file://" & expand_filename(src3_header_path),
      "range": {
         "start": {"line": 4, "character": 11},
         "end" : {"line": 4, "character": 11}
      }
   }])
)

run_test("textDocument/declaration: integer in local scope (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 34,
         "character": 17
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 33, "character": 20},
         "end" : {"line": 33, "character": 20}
      }
   }])
)

run_test("textDocument/declaration: integer in local scope (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 42,
         "character": 43
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 40, "character": 22},
         "end" : {"line": 40, "character": 22}
      }
   }])
)

run_test("textDocument/declaration: wire in local scope (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 32,
         "character": 46
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 31, "character": 17},
         "end" : {"line": 31, "character": 17}
      }
   }])
)

run_test("textDocument/declaration: wire in local scope (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 41,
         "character": 35
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 39, "character": 17},
         "end" : {"line": 39, "character": 17}
      }
   }])
)

run_test("textDocument/declaration: global wire used in local scope (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 32,
         "character": 19
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 28, "character": 9},
         "end" : {"line": 28, "character": 9}
      }
   }])
)

run_test("textDocument/declaration: global wire used in local scope (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 41,
         "character": 25
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 28, "character": 9},
         "end" : {"line": 28, "character": 9}
      }
   }])
)

run_test("textDocument/declaration: undeclared wire",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 48,
         "character": 19
      }
   }),
   new_lsp_response(39, 15, new_jnull())
)

run_test("textDocument/declaration: macro expansion (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 28
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 12, "character": 8},
         "end" : {"line": 12, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: macro expansion (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 31
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 12, "character": 28},
         "end" : {"line": 12, "character": 28}
      }
   }])
)

run_test("textDocument/declaration: macro expansion, out of bounds",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 29
      }
   }),
   new_lsp_response(39, 15, new_jnull())
)

run_test("textDocument/declaration: nested macro expansion (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 37,
         "character": 40
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 28, "character": 9},
         "end" : {"line": 28, "character": 9}
      }
   }])
)

run_test("textDocument/declaration: nested macro expansion (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 45,
         "character": 38
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 28, "character": 9},
         "end" : {"line": 28, "character": 9}
      }
   }])
)

run_test("textDocument/declaration: macro expansion, two on one line (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 51,
         "character": 28
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 12, "character": 28},
         "end" : {"line": 12, "character": 28}
      }
   }])
)

run_test("textDocument/declaration: macro expansion, two on one line (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 51,
         "character": 62
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 15, "character": 32},
         "end" : {"line": 15, "character": 32}
      }
   }])
)

run_test("textDocument/declaration: macro expansion, expression in argument (1)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 52,
         "character": 23
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 12, "character": 8},
         "end" : {"line": 12, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: macro expansion, expression in argument (2)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 52,
         "character": 33
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 12, "character": 28},
         "end" : {"line": 12, "character": 28}
      }
   }])
)

run_test("textDocument/declaration: macro expansion, expression in argument (3)",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 53,
         "character": 21
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 15, "character": 32},
         "end" : {"line": 15, "character": 32}
      }
   }])
)

run_test("textDocument/declaration: macro lookup, backtick",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 18
      }
   }),
   new_lsp_response(185, 15, %*[{
      "uri": "file://" & expand_filename(src3_header_path),
      "range": {
         "start": {"line": 2, "character": 8},
         "end" : {"line": 2, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: macro lookup, last character",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 21
      }
   }),
   new_lsp_response(185, 15, %*[{
      "uri": "file://" & expand_filename(src3_header_path),
      "range": {
         "start": {"line": 2, "character": 8},
         "end" : {"line": 2, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: macro lookup, in the middle",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 37,
         "character": 32
      }
   }),
   new_lsp_response(187, 15, %*[{
      "uri": "file://" & expand_filename(src3_header_path),
      "range": {
         "start": {"line": 17, "character": 8},
         "end" : {"line": 17, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: macro lookup, redefinition",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 57,
         "character": 19
      }
   }),
   new_lsp_response(188, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 56, "character": 12},
         "end" : {"line": 56, "character": 12}
      }
   }])
)

const src4_path = "./src/src4.v"
run_test("textDocument/declaration: module lookup",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 23,
         "character": 7
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src4_path),
      "range": {
         "start": {"line": 0, "character": 32},
         "end" : {"line": 0, "character": 32}
      }
   }])
)

run_test("textDocument/declaration: module port lookup",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 24,
         "character": 35
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src4_path),
      "range": {
         "start": {"line": 1, "character": 44},
         "end" : {"line": 1, "character": 44}
      }
   }])
)

run_test("textDocument/declaration: module port connection lookup",
   new_lsp_request(15, "textDocument/declaration", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 24,
         "character": 44
      }
   }),
   new_lsp_response(186, 15, %*[{
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 3, "character": 15},
         "end" : {"line": 3, "character": 15}
      }
   }])
)


# Shut down the server.
shutdown(ifs, ofs)

# Close the LSP server process.
close(vls)

# Print summary
styledWriteLine(stdout, styleBright, "\n----- SUMMARY -----")
var test_str = "test"
if nof_passed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_passed:<4} ", test_str,
                fgGreen, " PASSED")

test_str = "test"
if nof_failed == 1:
   test_str.add(' ')
else:
   test_str.add('s')
styledWriteLine(stdout, styleBright, &" {$nof_failed:<4} ", test_str,
                fgRed, " FAILED")

styledWriteLine(stdout, styleBright, "-------------------")

quit(nof_failed)
