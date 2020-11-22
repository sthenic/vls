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

Test suite: diagnostics
-----------------------""")

const src2_path = "./src/src2.v"
const src2_text = static_read(src2_path)
let src2_uri = construct_uri(expand_filename(src2_path))
let src2_uri_len = len(src2_uri)
run_test("src2.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": src2_uri,
         "languageId": "verilog",
         "version": 0,
         "text": src2_text
      }
   }),
   new_lsp_notification(1118 + src2_uri_len, "textDocument/publishDiagnostics", %*{
      "uri": src2_uri,
      "diagnostics": [
         {
            "message": "13:9: Undeclared module 'ERROR_WIDTH_IS_BAD_VALUE', assuming black box.",
            "severity": int(WARNING),
            "range": {
               "start": {"line": 12, "character": 8},
               "end" : {"line": 12, "character": 8}
            },
         },
         {
            "message": "78:9: Undeclared identifier 'tmp'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 77, "character": 8},
               "end" : {"line": 77, "character": 8}
            },
         },
         {
            "message": "78:16: Undeclared identifier 'tmp'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 77, "character": 15},
               "end" : {"line": 77, "character": 15}
            },
         },
         {
            "message": "88:16: Undeclared identifier 'rst_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 87, "character": 15},
               "end" : {"line": 87, "character": 15}
            },
         },
         {
            "message": "84:5: Missing parameter 'SOMETHING'.",
            "severity": int(WARNING),
            "range": {
               "start": {"line": 83, "character": 4},
               "end" : {"line": 83, "character": 4}
            },
         },
         {
            "message": "87:10: Unconnected input port 'clk_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 86, "character": 9},
               "end" : {"line": 86, "character": 9}
            },
         },
         {
            "message": "89:10: Unconnected input port 'data_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 88, "character": 9},
               "end" : {"line": 88, "character": 9}
            },
         }
      ]
   })
)


const src3_path = "./src/src3.v"
const src3_text = static_read(src3_path)
let src3_uri = construct_uri(expand_filename(src3_path))
let src3_uri_len = len(src3_uri)
run_test("src3.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": src3_uri,
         "languageId": "verilog",
         "version": 0,
         "text": src3_text
      }
   }),
   new_lsp_notification(252 + src3_uri_len, "textDocument/publishDiagnostics", %*{
      "uri": src3_uri,
      "diagnostics": [
         {
            "message": "49:16: Undeclared identifier 'an_undeclared_wire'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 48, "character": 15},
               "end" : {"line": 48, "character": 15}
            },
         }
      ]
   })
)


const src4_path = "./src/src4.v"
const src4_text = static_read(src4_path)
let src4_uri = construct_uri(expand_filename(src4_path))
let src4_uri_len = len(src4_uri)
run_test("src4.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": src4_uri,
         "languageId": "verilog",
         "version": 0,
         "text": src4_text
      }
   }),
   new_lsp_notification(244 + src4_uri_len, "textDocument/publishDiagnostics", %*{
      "uri": src4_uri,
      "diagnostics": [
         {
            "message": "15:34: Undeclared port 'LATE_DECLARATION'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 14, "character": 33},
               "end" : {"line": 14, "character": 33}
            },
         }
      ]
   })
)


const src5_path = "./src/src5.v"
const src5_text = static_read(src5_path)
let src5_uri = construct_uri(expand_filename(src5_path))
let src5_uri_len = len(src5_uri)
run_test("src5.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": src5_uri,
         "languageId": "verilog",
         "version": 0,
         "text": src5_text
      }
   }),
   new_lsp_notification(1640 + src5_uri_len, "textDocument/publishDiagnostics", %*{
      "uri": src5_uri,
      "diagnostics": [
         {
            "message": "18:18: Undeclared identifier 'from_module4'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 17, "character": 17},
               "end" : {"line": 17, "character": 17}
            },
         },
         {
            "message": "36:18: Undeclared identifier 'FOOBAR'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 35, "character": 17},
               "end" : {"line": 35, "character": 17}
            },
         },
         {
            "message": "16:5: Missing parameter 'MODULE4_PARAMETER'.",
            "severity": int(WARNING),
            "range": {
               "start": {"line": 15, "character": 4},
               "end" : {"line": 15, "character": 4}
            },
         },
         {
            "message": "27:5: Missing parameter 'WIDTH'.",
            "severity": int(WARNING),
            "range": {
               "start": {"line": 26, "character": 4},
               "end" : {"line": 26, "character": 4}
            },
         },
         {
            "message": "27:13: Missing port 'data_o'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 26, "character": 12},
               "end" : {"line": 26, "character": 12}
            },
         },
         {
            "message": "28:10: Unconnected input port 'clk_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 27, "character": 9},
               "end" : {"line": 27, "character": 9}
            },
         },
         {
            "message": "29:10: Unconnected input port 'data_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 28, "character": 9},
               "end" : {"line": 28, "character": 9}
            },
         },
         {
            "message": "44:16: Unassigned parameter 'WIDTH'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 43, "character": 15},
               "end" : {"line": 43, "character": 15}
            },
         },
         {
            "message": "44:25: Missing port 'clk_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 43, "character": 24},
               "end" : {"line": 43, "character": 24}
            },
         },
         {
            "message": "44:25: Missing port 'data_i'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 43, "character": 24},
               "end" : {"line": 43, "character": 24}
            },
         },
         {
            "message": "44:25: Missing port 'data_o'.",
            "severity": int(ERROR),
            "range": {
               "start": {"line": 43, "character": 24},
               "end" : {"line": 43, "character": 24}
            },
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
