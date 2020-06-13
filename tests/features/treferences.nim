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
   new_lsp_response(641, 0, %*[
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 4, "character": 15},
         "end" : {"line": 4, "character": 15}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 20, "character": 21},
         "end" : {"line": 20, "character": 21}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 49, "character": 21},
         "end" : {"line": 49, "character": 21}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 61, "character": 25},
         "end" : {"line": 61, "character": 25}
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
   new_lsp_response(641, 0, %*[
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 5, "character": 15},
         "end" : {"line": 5, "character": 15}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 21, "character": 12},
         "end" : {"line": 21, "character": 12}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 62, "character": 16},
         "end" : {"line": 62, "character": 16}
      }
   },
   {
      "uri": "file://" & expand_filename(src2_path),
      "range": {
         "start": {"line": 87, "character": 15},
         "end" : {"line": 87, "character": 15}
      }
   }
   ])
)


# What about something like:
#  `define FOO clk_i
#  .clk_i(FOO)
#

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
