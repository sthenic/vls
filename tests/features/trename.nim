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

# Open the file "./src/src3.v", expecting no parsing errors.
const src3_path = "./src/src3.v"
const src3_text = static_read(src3_path)
let src3_path_len = len(expand_filename(src3_path))
const src3_header_path = "./src/src3.vh"
let src3_header_path_len = len(expand_filename(src3_header_path))
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src3_path),
      "languageId": "verilog",
      "version": 0,
      "text": src3_text
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

Test suite: rename
------------------""")


run_test("textDocument/rename: port clk_i",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 17,
         "character": 23
      },
      "newName": "clock_in"
   }),
   new_lsp_response(536 + 3 * src3_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 3, "character": 15},
                     "end" : {"line": 3, "character": 20}
                  },
                  "newText": "clock_in"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 17, "character": 21},
                     "end" : {"line": 17, "character": 26}
                  },
                  "newText": "clock_in"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 24, "character": 41},
                     "end" : {"line": 24, "character": 46}
                  },
                  "newText": "clock_in"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: parameter defined in another file",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 15,
         "character": 23
      },
      "newName": "FOO_FROM_HEADER"
   }),
   new_lsp_response(388 + src3_header_path_len + src3_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_header_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 4, "character": 11},
                     "end" : {"line": 4, "character": 28}
                  },
                  "newText": "FOO_FROM_HEADER"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 15, "character": 9},
                     "end" : {"line": 15, "character": 26}
                  },
                  "newText": "FOO_FROM_HEADER"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: macro targeted at expansion location",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 52,
         "character": 16
      },
      "newName": "NEW_AND"
   }),
   new_lsp_response(1012 + 2 * src3_header_path_len + 4 * src3_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_header_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 2, "character": 8},
                     "end": {"line": 2, "character": 11}
                  },
                  "newText": "NEW_AND"
               }
            ]
         },
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 18, "character": 19},
                     "end": {"line": 18, "character": 22}
                  },
                  "newText": "NEW_AND"
               }
            ]
         },
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_header_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 17, "character": 26},
                     "end": {"line": 17, "character": 29}
                  },
                  "newText": "NEW_AND"
               }
            ]
         },
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 51, "character": 16},
                     "end": {"line": 51, "character": 19}
                  },
                  "newText": "NEW_AND"
               }
            ]
         },
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 51, "character": 37},
                     "end": {"line": 51, "character": 40}
                  },
                  "newText": "NEW_AND"
               }
            ]
         },
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 52, "character": 17},
                     "end": {"line": 52, "character": 20}
                  },
                  "newText": "NEW_AND"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: macro targeted at definition location",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 56,
         "character": 13
      },
      "newName": "NEW_AND"
   }),
   new_lsp_response(375 + 2 * src3_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 56, "character": 12},
                     "end": {"line": 56, "character": 15}
                  },
                  "newText": "NEW_AND"
               }
            ]
         },
         {
            "textDocument": {
               "version": new_jnull(),
               "uri": "file://" & expand_filename(src3_path)
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 57, "character": 17},
                     "end": {"line": 57, "character": 20}
                  },
                  "newText": "NEW_AND"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: wire used as macro argument",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 32
      },
      "newName": "new_one"
   }),
   new_lsp_response(1015 + 6 * src3_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 12, "character": 28},
                     "end" : {"line": 12, "character": 31}
                  },
                  "newText": "new_one"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 18, "character": 31},
                     "end" : {"line": 18, "character": 34}
                  },
                  "newText": "new_one"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 51, "character": 28},
                     "end" : {"line": 51, "character": 31}
                  },
                  "newText": "new_one"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 52, "character": 31},
                     "end" : {"line": 52, "character": 34}
                  },
                  "newText": "new_one"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 57, "character": 21},
                     "end" : {"line": 57, "character": 24}
                  },
                  "newText": "new_one"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src3_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 59, "character": 16},
                     "end" : {"line": 59, "character": 19}
                  },
                  "newText": "new_one"
               }
            ]
         }
      ]
   })
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
