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


const src4_path = "./src/src4.v"
let src4_path_len = len(expand_filename(src4_path))
const src5_path = "./src/src5.v"
let src5_path_len = len(expand_filename(src5_path))

run_test("textDocument/rename: module instance name",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 23,
         "character": 4
      },
      "newName": "new_module4"
   }),
   new_lsp_response(543 + src3_path_len + src4_path_len + src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 15, "character": 4},
                     "end" : {"line": 15, "character": 11}
                  },
                  "newText": "new_module4"
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
                     "start": {"line": 23, "character": 4},
                     "end" : {"line": 23, "character": 11}
                  },
                  "newText": "new_module4"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 0, "character": 32},
                     "end" : {"line": 0, "character": 39}
                  },
                  "newText": "new_module4"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: module port (clk_i)",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 24,
         "character": 34
      },
      "newName": "new_clk_i"
   }),
   new_lsp_response(861 + src3_path_len + 3 * src4_path_len + src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 16, "character": 34},
                     "end" : {"line": 16, "character": 39}
                  },
                  "newText": "new_clk_i"
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
                     "start": {"line": 24, "character": 34},
                     "end" : {"line": 24, "character": 39}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 1, "character": 44},
                     "end" : {"line": 1, "character": 49}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 7, "character": 21},
                     "end" : {"line": 7, "character": 26}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 16, "character": 16},
                     "end" : {"line": 16, "character": 21}
                  },
                  "newText": "new_clk_i"
               }
            ]
         }
      ]
   })
)

# Open the file "./src/src4.v", expecting no parsing errors.
const src4_text = static_read(src4_path)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src4_path),
      "languageId": "verilog",
      "version": 0,
      "text": src4_text
   }
}))
assert len(recv(ofs).parameters["diagnostics"]) == 0


run_test("textDocument/rename: module parameter port (FOO)",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 14,
         "character": 9
      },
      "newName": "new_fOO"
   }),
   new_lsp_response(532 + src4_path_len + 2 * src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 1, "character": 14},
                     "end" : {"line": 1, "character": 17}
                  },
                  "newText": "new_fOO"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 14, "character": 9},
                     "end" : {"line": 14, "character": 12}
                  },
                  "newText": "new_fOO"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 20, "character": 29},
                     "end" : {"line": 20, "character": 32}
                  },
                  "newText": "new_fOO"
               }
            ]
         }
      ]
   })
)



run_test("textDocument/rename: module name (from declaration)",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 0,
         "character": 32
      },
      "newName": "new_module4"
   }),
   new_lsp_response(543 + src3_path_len + src4_path_len + src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 15, "character": 4},
                     "end" : {"line": 15, "character": 11}
                  },
                  "newText": "new_module4"
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
                     "start": {"line": 23, "character": 4},
                     "end" : {"line": 23, "character": 11}
                  },
                  "newText": "new_module4"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 0, "character": 32},
                     "end" : {"line": 0, "character": 39}
                  },
                  "newText": "new_module4"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: module port, direct",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 1,
         "character": 45
      },
      "newName": "new_clk_i"
   }),
   new_lsp_response(861 + src3_path_len + 3 * src4_path_len + src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 16, "character": 34},
                     "end" : {"line": 16, "character": 39}
                  },
                  "newText": "new_clk_i"
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
                     "start": {"line": 24, "character": 34},
                     "end" : {"line": 24, "character": 39}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 1, "character": 44},
                     "end" : {"line": 1, "character": 49}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 7, "character": 21},
                     "end" : {"line": 7, "character": 26}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 16, "character": 16},
                     "end" : {"line": 16, "character": 21}
                  },
                  "newText": "new_clk_i"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: module port, indirect",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 7,
         "character": 23
      },
      "newName": "new_clk_i"
   }),
   new_lsp_response(861 + src3_path_len + 3 * src4_path_len + src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 16, "character": 34},
                     "end" : {"line": 16, "character": 39}
                  },
                  "newText": "new_clk_i"
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
                     "start": {"line": 24, "character": 34},
                     "end" : {"line": 24, "character": 39}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 1, "character": 44},
                     "end" : {"line": 1, "character": 49}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 7, "character": 21},
                     "end" : {"line": 7, "character": 26}
                  },
                  "newText": "new_clk_i"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 16, "character": 16},
                     "end" : {"line": 16, "character": 21}
                  },
                  "newText": "new_clk_i"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: localparam",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 11,
         "character": 15
      },
      "newName": "BAZ"
   }),
   new_lsp_response(367 + 2 * src4_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 11, "character": 15},
                     "end" : {"line": 11, "character": 18}
                  },
                  "newText": "BAZ"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 14, "character": 14},
                     "end" : {"line": 14, "character": 17}
                  },
                  "newText": "BAZ"
               }
            ]
         }
      ]
   })
)


# Open the file "./src/src5.v", expecting no parsing errors.
const src5_text = static_read(src5_path)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src5_path),
      "languageId": "verilog",
      "version": 0,
      "text": src5_text
   }
}))
assert len(recv(ofs).parameters["diagnostics"]) == 0


run_test("textDocument/rename: module parameter port, direct",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src5_path),
      },
      "position": {
         "line": 1,
         "character": 14
      },
      "newName": "new_fOO"
   }),
   new_lsp_response(532 + src4_path_len + 2 * src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 1, "character": 14},
                     "end" : {"line": 1, "character": 17}
                  },
                  "newText": "new_fOO"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 14, "character": 9},
                     "end" : {"line": 14, "character": 12}
                  },
                  "newText": "new_fOO"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 20, "character": 29},
                     "end" : {"line": 20, "character": 32}
                  },
                  "newText": "new_fOO"
               }
            ]
         }
      ]
   })
)


run_test("textDocument/rename: module parameter port, indirect",
   new_lsp_request(0, "textDocument/rename", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src5_path),
      },
      "position": {
         "line": 20,
         "character": 29
      },
      "newName": "new_fOO"
   }),
   new_lsp_response(532 + src4_path_len + 2 * src5_path_len, 0, %*{
      "documentChanges": [
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 1, "character": 14},
                     "end" : {"line": 1, "character": 17}
                  },
                  "newText": "new_fOO"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src4_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 14, "character": 9},
                     "end" : {"line": 14, "character": 12}
                  },
                  "newText": "new_fOO"
               }
            ]
         },
         {
            "textDocument": {
               "uri": "file://" & expand_filename(src5_path),
               "version": new_jnull()
            },
            "edits": [
               {
                  "range": {
                     "start": {"line": 20, "character": 29},
                     "end" : {"line": 20, "character": 32}
                  },
                  "newText": "new_fOO"
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
