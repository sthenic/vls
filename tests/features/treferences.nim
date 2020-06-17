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

Test suite: references
----------------------""")


run_test("textDocument/references: port (1)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 20,
         "character": 22
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(491, 0, %*[
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 20, "character": 21},
         "end" : {"line": 20, "character": 26}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 49, "character": 21},
         "end" : {"line": 49, "character": 26}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 30}
      }
   }
   ])
)


run_test("textDocument/references: port (2)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 5,
         "character": 17
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(339, 0, %*[
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 21, "character": 12},
         "end" : {"line": 21, "character": 17}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 62, "character": 16},
         "end" : {"line": 62, "character": 21}
      }
   }
   ])
)


run_test("textDocument/references: port (3) w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 5,
         "character": 17
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(489, 0, %*[
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 5, "character": 15},
         "end" : {"line": 5, "character": 20}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 21, "character": 12},
         "end" : {"line": 21, "character": 17}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 62, "character": 16},
         "end" : {"line": 62, "character": 21}
      }
   }
   ])
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

run_test("textDocument/references: reg (also used as macro argument)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 11
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(794, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 18, "character": 8},
         "end" : {"line": 18, "character": 14}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 18, "character": 23},
         "end" : {"line": 18, "character": 29}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 51, "character": 20},
         "end" : {"line": 51, "character": 26}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 52, "character": 21},
         "end" : {"line": 52, "character": 27}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 57, "character": 26},
         "end" : {"line": 57, "character": 32}
      }
   }
   ])
)


run_test("textDocument/references: reg (also used as macro argument) w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 11
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(945, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 12, "character": 8},
         "end" : {"line": 12, "character": 14}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 18, "character": 8},
         "end" : {"line": 18, "character": 14}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 18, "character": 23},
         "end" : {"line": 18, "character": 29}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 51, "character": 20},
         "end" : {"line": 51, "character": 26}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 52, "character": 21},
         "end" : {"line": 52, "character": 27}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 57, "character": 26},
         "end" : {"line": 57, "character": 32}
      }
   }
   ])
)


run_test("textDocument/references: reg (also used as an argument in a nested macro)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 32,
         "character": 23
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(643, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 32, "character": 19},
         "end" : {"line": 32, "character": 32}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 37, "character": 38},
         "end" : {"line": 37, "character": 51}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 41, "character": 19},
         "end" : {"line": 41, "character": 32}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 45, "character": 38},
         "end" : {"line": 45, "character": 51}
      }
   }
   ])
)


run_test("textDocument/references: reg (also used as an argument in a nested macro)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 59,
         "character": 17
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(947, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 18, "character": 31},
         "end" : {"line": 18, "character": 34}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 51, "character": 28},
         "end" : {"line": 51, "character": 31}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 52, "character": 31},
         "end" : {"line": 52, "character": 34}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 57, "character": 21},
         "end" : {"line": 57, "character": 24}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 59, "character": 16},
         "end" : {"line": 59, "character": 19}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 59, "character": 16},
         "end" : {"line": 59, "character": 19}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (1)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 60,
         "character": 22
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(339, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 60, "character": 21},
         "end" : {"line": 60, "character": 25}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 61, "character": 24},
         "end" : {"line": 61, "character": 28}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (2)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 52,
         "character": 19
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(949, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 18, "character": 18},
         "end" : {"line": 18, "character": 22}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_header_path),
      "range": {
         "start": {"line": 17, "character": 25},
         "end" : {"line": 17, "character": 29}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_header_path),
      "range": {
         "start": {"line": 17, "character": 25},
         "end" : {"line": 17, "character": 29}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 51, "character": 15},
         "end" : {"line": 51, "character": 19}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 51, "character": 36},
         "end" : {"line": 51, "character": 40}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 52, "character": 16},
         "end" : {"line": 52, "character": 20}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (3), redefined",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 57,
         "character": 17
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(187, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 57, "character": 16},
         "end" : {"line": 57, "character": 20}
      }
   }
   ])
)


run_test("textDocument/references: integer in local scope",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 42,
         "character": 24
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(643, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 17},
         "end" : {"line": 42, "character": 18}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 24},
         "end" : {"line": 42, "character": 25}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 39},
         "end" : {"line": 42, "character": 40}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 43},
         "end" : {"line": 42, "character": 44}
      }
   }
   ])
)


run_test("textDocument/references: integer in local scope (w/ declaration)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 42,
         "character": 24
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(795, 0, %*[
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 40, "character": 22},
         "end" : {"line": 40, "character": 23}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 17},
         "end" : {"line": 42, "character": 18}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 24},
         "end" : {"line": 42, "character": 25}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 39},
         "end" : {"line": 42, "character": 40}
      }
   },
   {
      "uri": "file://" & expand_filename(src3_path),
      "range": {
         "start": {"line": 42, "character": 43},
         "end" : {"line": 42, "character": 44}
      }
   }
   ])
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
