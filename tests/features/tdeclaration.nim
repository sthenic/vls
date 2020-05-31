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
      "uri": expand_filename(src2_path),
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


run_test("textDocument/declaration: port",
   new_lsp_request(0, "textDocument/declaration", %*{
      "textDocument": {
         "uri": expand_filename(src2_path),
      },
      "position": {
         "line": 20,
         "character": 22
      }
   }),
   new_lsp_response(178, 0, %*[{
      "uri": expand_filename(src2_path),
      "range": {
         "start": {"line": 4, "character": 15},
         "end" : {"line": 4, "character": 15}
      }
   }])
)


run_test("textDocument/declaration: reg",
   new_lsp_request(1, "textDocument/declaration", %*{
      "textDocument": {
         "uri": expand_filename(src2_path),
      },
      "position": {
         "line": 28,
         "character": 17
      }
   }),
   new_lsp_response(178, 1, %*[{
      "uri": expand_filename(src2_path),
      "range": {
         "start": {"line": 16, "character": 8},
         "end" : {"line": 16, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: reg (assignment)",
   new_lsp_request(2, "textDocument/declaration", %*{
      "textDocument": {
         "uri": expand_filename(src2_path),
      },
      "position": {
         "line": 22,
         "character": 22
      }
   }),
   new_lsp_response(178, 2, %*[{
      "uri": expand_filename(src2_path),
      "range": {
         "start": {"line": 15, "character": 8},
         "end" : {"line": 15, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: reg (array)",
   new_lsp_request(3, "textDocument/declaration", %*{
      "textDocument": {
         "uri": expand_filename(src2_path),
      },
      "position": {
         "line": 25,
         "character": 19
      }
   }),
   new_lsp_response(178, 3, %*[{
      "uri": expand_filename(src2_path),
      "range": {
         "start": {"line": 17, "character": 8},
         "end" : {"line": 17, "character": 8}
      }
   }])
)

run_test("textDocument/declaration: integer",
   new_lsp_request(3, "textDocument/declaration", %*{
      "textDocument": {
         "uri": expand_filename(src2_path),
      },
      "position": {
         "line": 25,
         "character": 26
      }
   }),
   new_lsp_response(180, 3, %*[{
      "uri": expand_filename(src2_path),
      "range": {
         "start": {"line": 18, "character": 12},
         "end" : {"line": 18, "character": 12}
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
