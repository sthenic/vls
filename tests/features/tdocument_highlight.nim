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

# Open the file "./src/src2.v".
const src2_path = "./src/src2.v"
const src2_text = static_read(src2_path)
let src2_uri = construct_uri(expand_filename(src2_path))
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": src2_uri,
      "languageId": "verilog",
      "version": 0,
      "text": src2_text
   }
}))
discard recv(ofs)

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

Test suite: document highlight
------------------------------""")


run_test("textDocument/documentHighlight: port (1)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src2_uri,
      },
      "position": {
         "line": 20,
         "character": 22
      }
   }),
   new_lsp_response(389, 0, %*[
   {
      "range": {
         "start": {"line": 4, "character": 15},
         "end" : {"line": 4, "character": 20}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 20, "character": 21},
         "end" : {"line": 20, "character": 26}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 49, "character": 21},
         "end" : {"line": 49, "character": 26}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 30}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: port (2)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src2_uri,
      },
      "position": {
         "line": 5,
         "character": 17
      }
   }),
   new_lsp_response(300, 0, %*[
   {
      "range": {
         "start": {"line": 5, "character": 15},
         "end" : {"line": 5, "character": 20}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 21, "character": 12},
         "end" : {"line": 21, "character": 17}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 62, "character": 16},
         "end" : {"line": 62, "character": 21}
      },
      "kind": int(LspHkText)
   }
   ])
)

# Open the file "./src/src3.v".
const src3_path = "./src/src3.v"
const src3_text = static_read(src3_path)
let src3_uri = construct_uri(expand_filename(src3_path))
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": src3_uri,
      "languageId": "verilog",
      "version": 0,
      "text": src3_text
   }
}))
discard recv(ofs)


run_test("textDocument/documentHighlight: reg (also used as macro argument)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 18,
         "character": 11
      }
   }),
   new_lsp_response(567, 0, %*[
   {
      "range": {
         "start": {"line": 12, "character": 8},
         "end" : {"line": 12, "character": 14}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 18, "character": 8},
         "end" : {"line": 18, "character": 14}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 18, "character": 23},
         "end" : {"line": 18, "character": 29}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 51, "character": 20},
         "end" : {"line": 51, "character": 26}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 52, "character": 21},
         "end" : {"line": 52, "character": 27}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 57, "character": 26},
         "end" : {"line": 57, "character": 32}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: reg (also used as an argument in a nested macro)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 32,
         "character": 23
      }
   }),
   new_lsp_response(479, 0, %*[
   {
      "range": {
         "start": {"line": 28, "character": 9},
         "end" : {"line": 28, "character": 22}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 32, "character": 19},
         "end" : {"line": 32, "character": 32}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 37, "character": 38},
         "end" : {"line": 37, "character": 51}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 41, "character": 19},
         "end" : {"line": 41, "character": 32}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 45, "character": 38},
         "end" : {"line": 45, "character": 51}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: reg (also used as an argument in a nested macro)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 59,
         "character": 17
      }
   }),
   new_lsp_response(569, 0, %*[
   {
      "range": {
         "start": {"line": 12, "character": 28},
         "end" : {"line": 12, "character": 31}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 18, "character": 31},
         "end" : {"line": 18, "character": 34}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 51, "character": 28},
         "end" : {"line": 51, "character": 31}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 52, "character": 31},
         "end" : {"line": 52, "character": 34}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 57, "character": 21},
         "end" : {"line": 57, "character": 24}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 59, "character": 16},
         "end" : {"line": 59, "character": 19}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: macro usage (1)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 60,
         "character": 22
      }
   }),
   new_lsp_response(302, 0, %*[
   {
      "range": {
         "start": {"line": 59, "character": 12},
         "end" : {"line": 59, "character": 15}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 60, "character": 22},
         "end" : {"line": 60, "character": 25}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 28}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: macro definition (1)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 59,
         "character": 14
      }
   }),
   new_lsp_response(302, 0, %*[
   {
      "range": {
         "start": {"line": 59, "character": 12},
         "end" : {"line": 59, "character": 15}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 60, "character": 22},
         "end" : {"line": 60, "character": 25}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 28}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: macro usage (2)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 52,
         "character": 19
      }
   }),
   new_lsp_response(391, 0, %*[
   {
      "range": {
         "start": {"line": 18, "character": 19},
         "end" : {"line": 18, "character": 22}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 51, "character": 16},
         "end" : {"line": 51, "character": 19}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 51, "character": 37},
         "end" : {"line": 51, "character": 40}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 52, "character": 17},
         "end" : {"line": 52, "character": 20}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: macro usage (3)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 57,
         "character": 17
      }
   }),
   new_lsp_response(213, 0, %*[
   {
      "range": {
         "start": {"line": 56, "character": 12},
         "end" : {"line": 56, "character": 15}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 57, "character": 17},
         "end" : {"line": 57, "character": 20}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: integer in local scope (w/ declaration)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 42,
         "character": 24
      }
   }),
   new_lsp_response(480, 0, %*[
   {
      "range": {
         "start": {"line": 40, "character": 22},
         "end" : {"line": 40, "character": 23}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 42, "character": 17},
         "end" : {"line": 42, "character": 18}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 42, "character": 24},
         "end" : {"line": 42, "character": 25}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 42, "character": 39},
         "end" : {"line": 42, "character": 40}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 42, "character": 43},
         "end" : {"line": 42, "character": 44}
      },
      "kind": int(LspHkText)
   }
   ])
)


run_test("textDocument/documentHighlight: undeclared)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 48,
         "character": 24
      }
   }),
   new_lsp_response(38, 0, new_jnull())
)


run_test("textDocument/documentHighlight: module port (1)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 24,
         "character": 37
      }
   }),
   new_lsp_response(38, 0, new_jnull())
)


run_test("textDocument/documentHighlight: module port connection",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 24,
         "character": 44
      }
   }),
   new_lsp_response(300, 0, %*[
   {
      "range": {
         "start": {"line": 3, "character": 15},
         "end" : {"line": 3, "character": 20}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 17, "character": 21},
         "end" : {"line": 17, "character": 26}
      },
      "kind": int(LspHkText)
   },
   {
      "range": {
         "start": {"line": 24, "character": 41},
         "end" : {"line": 24, "character": 46}
      },
      "kind": int(LspHkText)
   },
   ])
)


run_test("textDocument/documentHighlight: module port (2)",
   new_lsp_request(0, "textDocument/documentHighlight", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 25,
         "character": 11
      }
   }),
   new_lsp_response(38, 0, new_jnull())
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
