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


template run_test_unordered_compare(title: string, stimuli, reference: LspMessage) =
   # This test template only supports requests where the 'result' field is
   # a JSON array. The elements in this array are compared without regard to
   # their order.
   send(ifs, stimuli)
   let response =
      try:
         recv(ofs)
      except Exception as e:
         raise e

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
   new_lsp_response(81, 0, %*[
      {
         "label": "clk_i",
         "detail": "input wire clk_i"
      }
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
   new_lsp_response(235, 0, %*[
      {
         "label": "WIDTH",
         "detail": "parameter integer WIDTH = 0"
      },
      {
         "label": "WIDTH_FROM_HEADER",
         "detail": "localparam WIDTH_FROM_HEADER = 8",
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src3.vh"
         }
      }
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
   new_lsp_response(178, 0, %*[
      {
         "label": "WIDTH_FROM_HEADER",
         "detail": "localparam WIDTH_FROM_HEADER = 8",
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src3.vh"
         }
      }
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
   new_lsp_response(83, 0, %*[
      {
         "label": "my_reg",
         "detail": "reg my_reg = 1'b0"
      }
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


run_test_unordered_compare("textDocument/completion: include directive, browse path (1)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 13,
         "character": 15
      }
   }),
   new_lsp_response(188, 0, %*[
      {"label": "src0.v"},
      {"label": "src1.v"},
      {"label": "src2.v"},
      {"label": "src3.v"},
      {"label": "src3.vh"},
      {"label": "src4.v"},
      {"label": "src5.v"},
      {"label": "src6.v"},
   ])
)


run_test_unordered_compare("textDocument/completion: include directive, browse path (2)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 13,
         "character": 14
      }
   }),
   new_lsp_response(209, 0, %*[
      {"label": "include/"},
      {"label": "src0.v"},
      {"label": "src1.v"},
      {"label": "src2.v"},
      {"label": "src3.v"},
      {"label": "src3.vh"},
      {"label": "src4.v"},
      {"label": "src5.v"},
      {"label": "src6.v"},
   ])
)


run_test("textDocument/completion: module port (1)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 24,
         "character": 34
      }
   }),
   new_lsp_response(304, 0, %*[
      {
         "label": "clk_i ()",
         "detail": "(* another_attr = \"false\" *) input wire clk_i",
         "documentation": {
            "kind": "markdown",
            "value": "The clock input."
         }
      },
      {
         "label": "data_o ()",
         "detail": "output wire data_o",
         "documentation": {
            "kind": "markdown",
            "value": "The 1-bit data output port."
         }
      }
   ])
)


run_test("textDocument/completion: module port (2)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 25,
         "character": 10
      }
   }),
   new_lsp_response(161, 0, %*[
      {
         "label": "data_o ()",
         "detail": "output wire data_o",
         "documentation": {
            "kind": "markdown",
            "value": "The 1-bit data output port."
         }
      }
   ])
)

# Open the file "./src/src4.v", expecting no parsing errors.
const src4_path = "./src/src4.v"
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


run_test("textDocument/completion: module port (3), internal declarations",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 16,
         "character": 9
      }
   }),
   new_lsp_response(167, 0, %*[
      {
         "label": "clk_i ()",
         "detail": ".clk_i(clk_local)"
      },
      {
         "label": "data_o ()",
         "detail": "data_o"
      },
      {
         "label": "valid_o ()",
         "detail": "valid_o"
      }
   ])
)


run_test("textDocument/completion: module port (4), internal declarations",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 18,
         "character": 16
      }
   }),
   new_lsp_response(77, 0, %*[
      {
         "label": "valid_o ()",
         "detail": "valid_o"
      }
   ])
)


run_test("textDocument/completion: module parameter port (1)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 14,
         "character": 9
      }
   }),
   new_lsp_response(137, 0, %*[
      {
         "label": "FOO ()",
         "detail": "parameter FOO = 0"
      },
      {
         "label": "BaR ()",
         "detail": "parameter BaR = \"baz\""
      }
   ])
)


run_test("textDocument/completion: module parameter port (2)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 14,
         "character": 23
      }
   }),
   new_lsp_response(89, 0, %*[
      {
         "label": "BaR ()",
         "detail": "parameter BaR = \"baz\""
      }
   ])
)


run_test("textDocument/completion: w/ documentation",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 37,
         "character": 40
      }
   }),
   new_lsp_response(180, 0, %*[
      {
         "label": "a_common_wire",
         "detail": "wire a_common_wire",
         "documentation": {
            "kind": "markdown",
            "value": "This is the docstring for `a_common_wire`."
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
