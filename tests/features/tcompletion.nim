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

Test suite: completion
----------------------""")


run_test("textDocument/completion: c(lk_i)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 17,
         "character": 22
      }
   }),
   new_lsp_response(53, 0, %*[
      {"label": "clk_i"}
   ])
)


run_test("textDocument/completion: WIDTH",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 15,
         "character": 13
      }
   }),
   new_lsp_response(83, 0, %*[
      {"label": "WIDTH"},
      {"label": "WIDTH_FROM_HEADER"}
   ])
)


run_test("textDocument/completion: WIDTH_",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 15,
         "character": 15
      }
   }),
   new_lsp_response(65, 0, %*[
      {"label": "WIDTH_FROM_HEADER"}
   ])
)


run_test("textDocument/completion: macro argument (1)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 27
      }
   }),
   new_lsp_response(54, 0, %*[
      {"label": "my_reg"}
   ])
)


run_test("textDocument/completion: macro argument (2)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 53,
         "character": 30
      }
   }),
   new_lsp_response(57, 0, %*[
      {"label": "wider_reg"}
   ])
)


run_test("textDocument/completion: macro name (1)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 18,
         "character": 21
      }
   }),
   new_lsp_response(51, 0, %*[
      {"label": "AND"}
   ])
)


run_test("textDocument/completion: macro name (2)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 45,
         "character": 28
      }
   }),
   new_lsp_response(61, 0, %*[
      {"label": "AND_WITH_ZERO"}
   ])
)


run_test("textDocument/completion: include directive, browse path (1)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 13,
         "character": 15
      }
   }),
   new_lsp_response(169, 0, %*[
      {"label": "src0.v"},
      {"label": "src5.v"},
      {"label": "src2.v"},
      {"label": "src3.vh"},
      {"label": "src1.v"},
      {"label": "src3.v"},
      {"label": "src4.v"},
   ])
)


run_test("textDocument/completion: include directive, browse path (2)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 13,
         "character": 14
      }
   }),
   new_lsp_response(190, 0, %*[
      {"label": "src0.v"},
      {"label": "src5.v"},
      {"label": "src2.v"},
      {"label": "include/"},
      {"label": "src3.vh"},
      {"label": "src1.v"},
      {"label": "src3.v"},
      {"label": "src4.v"},
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
