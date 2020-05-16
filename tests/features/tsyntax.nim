import terminal
import strformat
import os
import osproc
import json

import ../../src/protocol
import ../../src/diagnostic
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

const src0_path = "./src/src0.v"
const src0_text = static_read(src0_path)
run_test("textDocument/didOpen: src0.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": expand_filename(src0_path),
         "languageId": "verilog",
         "version": 0,
         "text": src0_text
      }
   }),
   new_lsp_notification(282, "textDocument/publishDiagnostics", %*{
      "uri": expand_filename(src0_path),
      "diagnostics": [
         new_diagnostic(new_position(0, 0), new_position(0, 0), ERROR,
            "1:1: Unexpected token 'mod'."
         )
      ]
   })
)


const src1_path = "./src/src1.v"
const src1_text = static_read(src1_path)
run_test("textDocument/didOpen: src1.v",
   new_lsp_notification("textDocument/didOpen", %*{
      "textDocument": {
         "uri": expand_filename(src1_path),
         "languageId": "verilog",
         "version": 0,
         "text": src1_text
      }
   }),
   new_lsp_notification(726, "textDocument/publishDiagnostics", %*{
      "uri": expand_filename(src1_path),
      "diagnostics": [
         new_diagnostic(new_position(3, 0), new_position(3, 0), ERROR,
            "4:1: Expected token Symbol, got 'endmodule'."
         ),
         new_diagnostic(new_position(4, 0), new_position(4, 0), ERROR,
            "5:1: Expected token Symbol, got '[EOF]'."
         ),
         new_diagnostic(new_position(4, 0), new_position(4, 0), ERROR,
            "5:1: Expected token ';', got '[EOF]'."
         ),
         new_diagnostic(new_position(4, 0), new_position(4, 0), ERROR,
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
