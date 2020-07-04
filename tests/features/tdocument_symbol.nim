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

# Open the file "./src/src4.v", expecting no parsing errors.
const src4_path = "./src/src4.v"
const src4_text = static_read(src4_path)
let src4_path_len = len(expand_filename(src4_path))
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src4_path),
      "languageId": "verilog",
      "version": 0,
      "text": src4_text
   }
}))
assert len(recv(ofs).parameters["diagnostics"]) == 0

template run_test(title: string, stimuli, reference: LspMessage) =
   send(ifs, stimuli)
   let response =
      try:
         recv(ofs)
      except Exception as e:
         raise e
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

Test suite: document symbols
----------------------------""")

run_test("textDocument/documentSymbol",
   new_lsp_request(0, "textDocument/documentSymbol", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      }
   }),
   new_lsp_response(1093 + 8 * src4_path_len, 0, %*[
   {
      "name": "module4",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 0,
               "character": 32
            },
            "end": {
               "line": 0,
               "character": 39
            }
         }
      }
   },
   {
      "name": "clk_i",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 1,
               "character": 44
            },
            "end": {
               "line": 1,
               "character": 49
            }
         }
      }
   },
   {
      "name": "data_o",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 2,
               "character": 16
            },
            "end": {
               "line": 2,
               "character": 22
            }
         }
      }
   },
   {
      "name": "tmp",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 5,
               "character": 8
            },
            "end": {
               "line": 5,
               "character": 11
            }
         }
      }
   },
   {
      "name": "BAR",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 10,
               "character": 15
            },
            "end": {
               "line": 10,
               "character": 18
            }
         }
      }
   },
   {
      "name": "fOO",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 10,
               "character": 25
            },
            "end": {
               "line": 10,
               "character": 28
            }
         }
      }
   },
   {
      "name": "out",
      "kind": 13,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 11,
               "character": 15
            },
            "end": {
               "line": 11,
               "character": 18
            }
         }
      }
   },
   {
      "name": "module5",
      "kind": 2,
      "location": {
         "uri": "file://" & expand_filename(src4_path),
         "range": {
            "start": {
               "line": 12,
               "character": 4
            },
            "end": {
               "line": 12,
               "character": 11
            }
         }
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