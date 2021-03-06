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

Test suite: syntax
------------------""")


const src0_path = "./src/src0.v"
const src0_text = static_read(src0_path)
let src0_uri = construct_uri(expand_filename(src0_path))
let src0_uri_len = len(src0_uri)
run_test("textDocument/didOpen: src0.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": src0_uri,
         "languageId": "verilog",
         "version": 0,
         "text": src0_text
      }
   }),
   new_lsp_notification(226 + src0_uri_len, "textDocument/publishDiagnostics", %*{
      "uri": src0_uri,
      "diagnostics": [
         new_lsp_diagnostic(new_lsp_position(0, 0), new_lsp_position(0, 0), ERROR,
            "1:1: Unexpected token 'mod'."
         )
      ]
   })
)


const src1_path = "./src/src1.v"
const src1_text = static_read(src1_path)
let src1_uri = construct_uri(expand_filename(src1_path))
let src1_uri_len = len(src1_uri)
run_test("textDocument/didOpen: src1.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": src1_uri,
         "languageId": "verilog",
         "version": 0,
         "text": src1_text
      }
   }),
   new_lsp_notification(670 + src1_uri_len, "textDocument/publishDiagnostics", %*{
      "uri": src1_uri,
      "diagnostics": [
         new_lsp_diagnostic(new_lsp_position(3, 0), new_lsp_position(3, 0), ERROR,
            "4:1: Expected token Symbol, got 'endmodule'."
         ),
         new_lsp_diagnostic(new_lsp_position(4, 0), new_lsp_position(4, 0), ERROR,
            "5:1: Expected token Symbol, got '[EOF]'."
         ),
         new_lsp_diagnostic(new_lsp_position(4, 0), new_lsp_position(4, 0), ERROR,
            "5:1: Expected token ';', got '[EOF]'."
         ),
         new_lsp_diagnostic(new_lsp_position(4, 0), new_lsp_position(4, 0), ERROR,
            "5:1: Expected token 'endmodule', got '[EOF]'."
         )
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
