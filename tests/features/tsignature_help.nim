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
      "uri": "file://" & expand_filename(src2_path),
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


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: signature help
--------------------------""")


run_test("textDocument/signatureHelp: task",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 44,
         "character": 17
      }
   }),
   new_lsp_response(217, 15, %*{
      "signatures": [
         {
            "label": "task an_empty_task()",
            "documentation": {
               "kind": "markdown",
               "value": "Docstring to `an_empty_task`."
            },
            "parameters": []
         }
      ],
      "activeSignature": 0,
      "activeParameter": -1
   })
)


run_test("textDocument/signatureHelp: function name",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 50,
         "character": 27
      }
   }),
   new_lsp_response(316, 15, %*{
      "signatures": [
         {
            "label": "function automatic [WIDTH - 1:0] add_one(input a)",
            "documentation": {
               "kind": "markdown",
               "value": "Docstring to function `add_one`."
            },
            "parameters": [
               {
                  "label": "input a",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": -1
   })
)


run_test("textDocument/signatureHelp: function parameter",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 50,
         "character": 33
      }
   }),
   new_lsp_response(315, 15, %*{
      "signatures": [
         {
            "label": "function automatic [WIDTH - 1:0] add_one(input a)",
            "documentation": {
               "kind": "markdown",
               "value": "Docstring to function `add_one`."
            },
            "parameters": [
               {
                  "label": "input a",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 0
   })
)

# Open the file "./src/src6.v", expecting some errors since a broken AST is part
# of what we want to test.
const src6_path = "./src/src6.v"
const src6_text = static_read(src6_path)
send(ifs, new_lsp_notification("textDocument/didOpen", %*{
   "textDocument": {
      "uri": "file://" & expand_filename(src6_path),
      "languageId": "verilog",
      "version": 0,
      "text": src6_text
   }
}))
discard recv(ofs)


run_test("textDocument/signatureHelp: function w/ multiple parameters (1)",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 22,
         "character": 57
      }
   }),
   new_lsp_response(494, 15, %*{
      "signatures": [
         {
            "label": "function [FOO:0] compute_something(input [FOO - 1:0] parameter1, input [FOO - 1:0] parameter2)",
            "documentation": {
               "kind": "markdown",
               "value": "Compute something between `parameter1` and `parameter2`."
            },
            "parameters": [
               {
                  "label": "input [FOO - 1:0] parameter1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO - 1:0] parameter2",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 0
   })
)


run_test("textDocument/signatureHelp: function w/ multiple parameters (2)",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 22,
         "character": 58
      }
   }),
   new_lsp_response(494, 15, %*{
      "signatures": [
         {
            "label": "function [FOO:0] compute_something(input [FOO - 1:0] parameter1, input [FOO - 1:0] parameter2)",
            "documentation": {
               "kind": "markdown",
               "value": "Compute something between `parameter1` and `parameter2`."
            },
            "parameters": [
               {
                  "label": "input [FOO - 1:0] parameter1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO - 1:0] parameter2",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 1
   })
)


run_test("textDocument/signatureHelp: task w/ multiple parameters (1)",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 23,
         "character": 16
      }
   }),
   new_lsp_response(567, 15, %*{
      "signatures": [
         {
            "label": "task do_work(input [FOO:0] input1, input [FOO:0] input2, output [FOO:0] result)",
            "documentation": {
               "kind": "markdown",
               "value": "Do some work provided `input1` and `input2`. The output is stored in `result`."
            },
            "parameters": [
               {
                  "label": "input [FOO:0] input1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO:0] input2",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "output [FOO:0] result",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 0
   })
)


run_test("textDocument/signatureHelp: task w/ multiple parameters (2)",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 23,
         "character": 44
      }
   }),
   new_lsp_response(567, 15, %*{
      "signatures": [
         {
            "label": "task do_work(input [FOO:0] input1, input [FOO:0] input2, output [FOO:0] result)",
            "documentation": {
               "kind": "markdown",
               "value": "Do some work provided `input1` and `input2`. The output is stored in `result`."
            },
            "parameters": [
               {
                  "label": "input [FOO:0] input1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO:0] input2",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "output [FOO:0] result",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 1
   })
)


run_test("textDocument/signatureHelp: task w/ multiple parameters (3)",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 23,
         "character": 68
      }
   }),
   new_lsp_response(567, 15, %*{
      "signatures": [
         {
            "label": "task do_work(input [FOO:0] input1, input [FOO:0] input2, output [FOO:0] result)",
            "documentation": {
               "kind": "markdown",
               "value": "Do some work provided `input1` and `input2`. The output is stored in `result`."
            },
            "parameters": [
               {
                  "label": "input [FOO:0] input1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO:0] input2",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "output [FOO:0] result",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 2
   })
)


run_test("textDocument/signatureHelp: task signature, concatenated argument",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 27,
         "character": 29
      }
   }),
   new_lsp_response(567, 15, %*{
      "signatures": [
         {
            "label": "task do_work(input [FOO:0] input1, input [FOO:0] input2, output [FOO:0] result)",
            "documentation": {
               "kind": "markdown",
               "value": "Do some work provided `input1` and `input2`. The output is stored in `result`."
            },
            "parameters": [
               {
                  "label": "input [FOO:0] input1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO:0] input2",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "output [FOO:0] result",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 0
   })
)


run_test("textDocument/signatureHelp: task signature w/ broken AST",
   new_lsp_request(15, "textDocument/signatureHelp", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src6_path),
      },
      "position": {
         "line": 27,
         "character": 43
      }
   }),
   new_lsp_response(567, 15, %*{
      "signatures": [
         {
            "label": "task do_work(input [FOO:0] input1, input [FOO:0] input2, output [FOO:0] result)",
            "documentation": {
               "kind": "markdown",
               "value": "Do some work provided `input1` and `input2`. The output is stored in `result`."
            },
            "parameters": [
               {
                  "label": "input [FOO:0] input1",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "input [FOO:0] input2",
                  "documentation": {"kind": "plaintext", "value": ""}
               },
               {
                  "label": "output [FOO:0] result",
                  "documentation": {"kind": "plaintext", "value": ""}
               }
            ]
         }
      ],
      "activeSignature": 0,
      "activeParameter": 1
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
