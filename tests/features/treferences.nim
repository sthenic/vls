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
let src2_uri_len = len(src2_uri)
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
   if unordered_compare(response, reference):
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
         "uri": src2_uri,
      },
      "position": {
         "line": 20,
         "character": 22
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(302 + 3 * src2_uri_len, 0, %*[
   {
      "uri": src2_uri,
      "range": {
         "start": {"line": 20, "character": 21},
         "end" : {"line": 20, "character": 26}
      }
   },
   {
      "uri": src2_uri,
      "range": {
         "start": {"line": 49, "character": 21},
         "end" : {"line": 49, "character": 26}
      }
   },
   {
      "uri": src2_uri,
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
         "uri": src2_uri,
      },
      "position": {
         "line": 5,
         "character": 17
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(213 + 2 * src2_uri_len, 0, %*[
   {
      "uri": src2_uri,
      "range": {
         "start": {"line": 21, "character": 12},
         "end" : {"line": 21, "character": 17}
      }
   },
   {
      "uri": src2_uri,
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
         "uri": src2_uri,
      },
      "position": {
         "line": 5,
         "character": 17
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(300 + 3 * src2_uri_len, 0, %*[
   {
      "uri": src2_uri,
      "range": {
         "start": {"line": 5, "character": 15},
         "end" : {"line": 5, "character": 20}
      }
   },
   {
      "uri": src2_uri,
      "range": {
         "start": {"line": 21, "character": 12},
         "end" : {"line": 21, "character": 17}
      }
   },
   {
      "uri": src2_uri,
      "range": {
         "start": {"line": 62, "character": 16},
         "end" : {"line": 62, "character": 21}
      }
   }
   ])
)

# Open the file "./src/src3.v".
const src3_path = "./src/src3.v"
const src3_header_path = "./src/src3.vh"
const src3_text = static_read(src3_path)
let src3_uri = construct_uri(expand_filename(src3_path))
let src3_header_uri = construct_uri(expand_filename(src3_header_path))
let src3_uri_len = len(src3_uri)
let src3_header_uri_len = len(src3_header_uri)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": src3_uri,
      "languageId": "verilog",
      "version": 0,
      "text": src3_text
   }
}))
discard recv(ofs)

run_test("textDocument/references: reg (also used as macro argument)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 18,
         "character": 11
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(479 + 5 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 8},
         "end" : {"line": 18, "character": 14}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 23},
         "end" : {"line": 18, "character": 29}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 20},
         "end" : {"line": 51, "character": 26}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 52, "character": 21},
         "end" : {"line": 52, "character": 27}
      }
   },
   {
      "uri": src3_uri,
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
         "uri": src3_uri,
      },
      "position": {
         "line": 18,
         "character": 11
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(567 + 6 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 12, "character": 8},
         "end" : {"line": 12, "character": 14}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 8},
         "end" : {"line": 18, "character": 14}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 23},
         "end" : {"line": 18, "character": 29}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 20},
         "end" : {"line": 51, "character": 26}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 52, "character": 21},
         "end" : {"line": 52, "character": 27}
      }
   },
   {
      "uri": src3_uri,
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
         "uri": src3_uri,
      },
      "position": {
         "line": 32,
         "character": 23
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(391 + 4 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 32, "character": 19},
         "end" : {"line": 32, "character": 32}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 37, "character": 38},
         "end" : {"line": 37, "character": 51}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 41, "character": 19},
         "end" : {"line": 41, "character": 32}
      }
   },
   {
      "uri": src3_uri,
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
         "uri": src3_uri,
      },
      "position": {
         "line": 59,
         "character": 17
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(480 + 5 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 31},
         "end" : {"line": 18, "character": 34}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 28},
         "end" : {"line": 51, "character": 31}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 52, "character": 31},
         "end" : {"line": 52, "character": 34}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 57, "character": 21},
         "end" : {"line": 57, "character": 24}
      }
   },
   {
      "uri": src3_uri,
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
         "uri": src3_uri,
      },
      "position": {
         "line": 60,
         "character": 22
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(213 + 2 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 60, "character": 22},
         "end" : {"line": 60, "character": 25}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 28}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (1) w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 60,
         "character": 22
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(302 + 3 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 59, "character": 12},
         "end" : {"line": 59, "character": 15}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 60, "character": 22},
         "end" : {"line": 60, "character": 25}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 28}
      }
   }
   ])
)


run_test("textDocument/references: macro definition (1) w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 59,
         "character": 14
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(302 + 3 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 59, "character": 12},
         "end" : {"line": 59, "character": 15}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 60, "character": 22},
         "end" : {"line": 60, "character": 25}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 28}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (2)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 52,
         "character": 19
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(480 + 4 * src3_uri_len + src3_header_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 19},
         "end" : {"line": 18, "character": 22}
      }
   },
   {
      "uri": src3_header_uri,
      "range": {
         "start": {"line": 17, "character": 26},
         "end" : {"line": 17, "character": 29}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 16},
         "end" : {"line": 51, "character": 19}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 37},
         "end" : {"line": 51, "character": 40}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 52, "character": 17},
         "end" : {"line": 52, "character": 20}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (2) w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 52,
         "character": 19
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(566 + 4 * src3_uri_len + 2 * src3_header_uri_len, 0, %*[
   {
      "uri": src3_header_uri,
      "range": {
         "start": {"line": 2, "character": 8},
         "end" : {"line": 2, "character": 11}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 18, "character": 19},
         "end" : {"line": 18, "character": 22}
      }
   },
   {
      "uri": src3_header_uri,
      "range": {
         "start": {"line": 17, "character": 26},
         "end" : {"line": 17, "character": 29}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 16},
         "end" : {"line": 51, "character": 19}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 51, "character": 37},
         "end" : {"line": 51, "character": 40}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 52, "character": 17},
         "end" : {"line": 52, "character": 20}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (3), redefined",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 57,
         "character": 17
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(124 + src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 57, "character": 17},
         "end" : {"line": 57, "character": 20}
      }
   }
   ])
)


run_test("textDocument/references: macro usage (3), redefined w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 57,
         "character": 17
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(213 + 2 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 56, "character": 12},
         "end" : {"line": 56, "character": 15}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 57, "character": 17},
         "end" : {"line": 57, "character": 20}
      }
   }
   ])
)


run_test("textDocument/references: integer in local scope",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 42,
         "character": 24
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(391 + 4 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 17},
         "end" : {"line": 42, "character": 18}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 24},
         "end" : {"line": 42, "character": 25}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 39},
         "end" : {"line": 42, "character": 40}
      }
   },
   {
      "uri": src3_uri,
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
         "uri": src3_uri,
      },
      "position": {
         "line": 42,
         "character": 24
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(480 + 5 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 40, "character": 22},
         "end" : {"line": 40, "character": 23}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 17},
         "end" : {"line": 42, "character": 18}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 24},
         "end" : {"line": 42, "character": 25}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 39},
         "end" : {"line": 42, "character": 40}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 42, "character": 43},
         "end" : {"line": 42, "character": 44}
      }
   }
   ])
)


run_test("textDocument/references: undeclared)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 48,
         "character": 24
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(38, 0, new_jnull())
)


run_test("textDocument/references: module port (1)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 24,
         "character": 37
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(38, 0, new_jnull())
)


run_test("textDocument/references: module port connection",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 24,
         "character": 44
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(300 + 3 * src3_uri_len, 0, %*[
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 3, "character": 15},
         "end" : {"line": 3, "character": 20}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 17, "character": 21},
         "end" : {"line": 17, "character": 26}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 24, "character": 41},
         "end" : {"line": 24, "character": 46}
      }
   },
   ])
)


run_test("textDocument/references: module port (2)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 25,
         "character": 11
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(38, 0, new_jnull())
)


# Open the file "./src/src4.v".
const src4_path = "./src/src4.v"
const src4_text = static_read(src4_path)
let src4_uri = construct_uri(expand_filename(src4_path))
let src4_uri_len = len(src4_uri)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": src4_uri,
      "languageId": "verilog",
      "version": 0,
      "text": src4_text
   }
}))
discard recv(ofs)

const src5_path = "./src/src5.v"
const src5_text = static_read(src5_path)
let src5_uri = construct_uri(expand_filename(src5_path))
let src5_uri_len = len(src5_uri)
run_test("textDocument/references: module instantiation",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 23,
         "character": 6
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(213 + src3_uri_len + src5_uri_len, 0, %*[
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 15, "character": 12},
         "end" : {"line": 15, "character": 24}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 23, "character": 38},
         "end" : {"line": 23, "character": 50}
      }
   }
   ])
)

run_test("textDocument/references: module instantiation w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src3_uri,
      },
      "position": {
         "line": 23,
         "character": 6
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(300 + src3_uri_len + src5_uri_len + src4_uri_len, 0, %*[
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 15, "character": 12},
         "end" : {"line": 15, "character": 24}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 23, "character": 38},
         "end" : {"line": 23, "character": 50}
      }
   },
   {
      "uri": src4_uri,
      "range": {
         "start": {"line": 0, "character": 32},
         "end" : {"line": 0, "character": 39}
      }
   }
   ])
)

run_test("textDocument/references: module declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src4_uri,
      },
      "position": {
         "line": 0,
         "character": 32
      },
      "context": {
         "includeDeclaration": false
      }
   }),
   new_lsp_response(213 + src3_uri_len + src5_uri_len, 0, %*[
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 15, "character": 12},
         "end" : {"line": 15, "character": 24}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 23, "character": 38},
         "end" : {"line": 23, "character": 50}
      }
   }
   ])
)

run_test("textDocument/references: module declaration w/ declaration",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src4_uri,
      },
      "position": {
         "line": 0,
         "character": 32
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(300 + src3_uri_len + src5_uri_len + src4_uri_len, 0, %*[
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 15, "character": 12},
         "end" : {"line": 15, "character": 24}
      }
   },
   {
      "uri": src3_uri,
      "range": {
         "start": {"line": 23, "character": 38},
         "end" : {"line": 23, "character": 50}
      }
   },
   {
      "uri": src4_uri,
      "range": {
         "start": {"line": 0, "character": 32},
         "end" : {"line": 0, "character": 39}
      }
   }
   ])
)

run_test("textDocument/references: localparam w/ same name as a parameter port",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src4_uri,
      },
      "position": {
         "line": 11,
         "character": 26
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(213 + 2 * src4_uri_len, 0, %*[
   {
      "uri": src4_uri,
      "range": {
         "start": {"line": 11, "character": 25},
         "end" : {"line": 11, "character": 28}
      }
   },
   {
      "uri": src4_uri,
      "range": {
         "start": {"line": 14, "character": 26},
         "end" : {"line": 14, "character": 29}
      }
   }
   ])
)


# Open the file "./src/src5.v".
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": src5_uri,
      "languageId": "verilog",
      "version": 0,
      "text": src5_text
   }
}))
discard recv(ofs)


run_test("textDocument/references: port reference (from reference)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src5_uri,
      },
      "position": {
         "line": 3,
         "character": 19
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(387 + 4 * src5_uri_len, 0, %*[
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 3, "character": 11},
         "end" : {"line": 3, "character": 20}
      }
   },
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 6, "character": 15},
         "end" : {"line": 6, "character": 24}
      }
   },
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 11, "character": 21},
         "end" : {"line": 11, "character": 30}
      }
   },
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 16, "character": 41},
         "end" : {"line": 16, "character": 50}
      }
   }
   ])
)

run_test("textDocument/references: port reference (from declaration)",
   new_lsp_request(0, "textDocument/references", %*{
      "textDocument": {
         "uri": src5_uri,
      },
      "position": {
         "line": 6,
         "character": 15
      },
      "context": {
         "includeDeclaration": true
      }
   }),
   new_lsp_response(387 + 4 * src5_uri_len, 0, %*[
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 3, "character": 11},
         "end" : {"line": 3, "character": 20}
      }
   },
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 6, "character": 15},
         "end" : {"line": 6, "character": 24}
      }
   },
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 11, "character": 21},
         "end" : {"line": 11, "character": 30}
      }
   },
   {
      "uri": src5_uri,
      "range": {
         "start": {"line": 16, "character": 41},
         "end" : {"line": 16, "character": 50}
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
