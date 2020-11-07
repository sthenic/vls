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
   new_lsp_response(90, 0, %*[
      {
         "label": "clk_i",
         "detail": "input wire clk_i",
         "kind": int(LspCkInterface)
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
   new_lsp_response(289, 0, %*[
      {
         "label": "WIDTH",
         "detail": "parameter integer WIDTH = 0",
         "kind": int(LspCkConstant)
      },
      {
         "label": "WIDTH_FROM_HEADER",
         "detail": "localparam WIDTH_FROM_HEADER = 8",
         "documentation": {
            "kind": "markdown",
            "value": "Docstring for `WIDTH_FROM_HEADER`.\n\n---\nFile: src3.vh",
         },
         "kind": int(LspCkConstant)
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
   new_lsp_response(222, 0, %*[
      {
         "label": "WIDTH_FROM_HEADER",
         "detail": "localparam WIDTH_FROM_HEADER = 8",
         "documentation": {
            "kind": "markdown",
            "value": "Docstring for `WIDTH_FROM_HEADER`.\n\n---\nFile: src3.vh"
         },
         "kind": int(LspCkConstant)
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
   new_lsp_response(92, 0, %*[
      {
         "label": "my_reg",
         "detail": "reg my_reg = 1'b0",
         "kind": int(LspCkVariable)
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
   new_lsp_response(121, 0, %*[
      {
         "label": "wider_reg",
         "detail": "reg [WIDTH_FROM_HEADER - 1:0] wider_reg = 0",
         "kind": int(LspCkVariable)
      }
   ])
)


run_test("textDocument/completion: macro argument (3)",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 52,
         "character": 34
      }
   }),
   new_lsp_response(87, 0, %*[
      {
         "label": "one",
         "detail": "wire one = 1'b1",
         "kind": int(LspCkVariable)
      }
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
   new_lsp_response(60, 0, %*[
      {
         "label": "AND",
         "kind": int(LspCkText)
      }
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
   new_lsp_response(70, 0, %*[
      {
         "label": "AND_WITH_ZERO",
         "kind": int(LspCkText)
      }
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
   new_lsp_response(297, 0, %*[
      {
         "label": "src0.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src1.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src2.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src3.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src3.vh",
         "kind": int(LspCkFile)
      },
      {
         "label": "src4.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src5.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src6.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src7.v",
         "kind": int(LspCkFile)
      },
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
   new_lsp_response(328, 0, %*[
      {
         "label": "include/",
         "kind": int(LspCkFile)
      },
      {
         "label": "src0.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src1.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src2.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src3.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src3.vh",
         "kind": int(LspCkFile)
      },
      {
         "label": "src4.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src5.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src6.v",
         "kind": int(LspCkFile)
      },
      {
         "label": "src7.v",
         "kind": int(LspCkFile)
      },
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
   new_lsp_response(364, 0, %*[
      {
         "label": "clk_i ()",
         "detail": "(* another_attr = \"false\" *) input wire clk_i",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "The clock input.\n\n---\nFile: src4.v"
         }
      },
      {
         "label": "data_o ()",
         "detail": "output wire data_o",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "The 1-bit data output port.\n\n---\nFile: src4.v"
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
   new_lsp_response(191, 0, %*[
      {
         "label": "data_o ()",
         "detail": "output wire data_o",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "The 1-bit data output port.\n\n---\nFile: src4.v"
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
   new_lsp_response(555, 0, %*[
      {
         "label": "clk_i ()",
         "detail": ".clk_i(clk_local)",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
      },
      {
         "label": "split_port_i ()",
         "detail": ".split_port_i({first_half, second_half})",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
      },
      {
         "label": "data_o ()",
         "detail": "data_o",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
      },
      {
         "label": "valid_o ()",
         "detail": "valid_o",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
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
   new_lsp_response(154, 0, %*[
      {
         "label": "valid_o ()",
         "detail": "valid_o",
         "kind": int(LspCkInterface),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
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
   new_lsp_response(313, 0, %*[
      {
         "label": "FOO ()",
         "detail": "parameter FOO = 0",
         "kind": int(LspCkConstant),
         "documentation": {
            "kind": "markdown",
            "value": "Docstring for `FOO`.\n\n---\nFile: src5.v"
         }
      },
      {
         "label": "BaR ()",
         "detail": "parameter BaR = \"baz\"",
         "kind": int(LspCkConstant),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
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
   new_lsp_response(167, 0, %*[
      {
         "label": "BaR ()",
         "detail": "parameter BaR = \"baz\"",
         "kind": int(LspCkConstant),
         "documentation": {
            "kind": "markdown",
            "value": "\n\n---\nFile: src5.v"
         }
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
   new_lsp_response(189, 0, %*[
      {
         "label": "a_common_wire",
         "detail": "wire a_common_wire",
         "kind": int(LspCkVariable),
         "documentation": {
            "kind": "markdown",
            "value": "This is the docstring for `a_common_wire`."
         }
      }
   ])
)


run_test("textDocument/completion: local scope",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 41,
         "character": 37
      }
   }),
   new_lsp_response(259, 0, %*[
      {
         "label": "a_common_wire",
         "detail": "wire a_common_wire",
         "kind": int(LspCkVariable),
         "documentation": {
            "kind": "markdown",
            "value": "This is the docstring for `a_common_wire`."
         }
      },
      {
         "label": "a_local_wire",
         "detail": "wire a_local_wire = 1'b1",
         "kind": int(LspCkVariable),
      }
   ])
)


run_test("textDocument/completion: ignore declarations in local scope",
   new_lsp_request(0, "textDocument/completion", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 61,
         "character": 10
      }
   }),
   new_lsp_response(189, 0, %*[
      {
         "label": "a_common_wire",
         "detail": "wire a_common_wire",
         "kind": int(LspCkVariable),
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
