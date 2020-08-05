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

Test suite: hover
-----------------""")


run_test("textDocument/hover: port identifier",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 17,
         "character": 25
      }
   }),
   new_lsp_response(189, 15, %*{
      "range": {
         "start": {"line": 17, "character": 21},
         "end" : {"line": 17, "character": 26}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
input wire clk_i
```"""
      }
   })
)


run_test("textDocument/hover: reg identifier",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 19,
         "character": 29
      }
   }),
   new_lsp_response(216, 15, %*{
      "range": {
         "start": {"line": 19, "character": 21},
         "end" : {"line": 19, "character": 30}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
reg [WIDTH_FROM_HEADER - 1:0] wider_reg = 0
```"""
      }
   })
)


run_test("textDocument/hover: identifier in macro",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 37,
         "character": 44
      }
   }),
   new_lsp_response(237, 15, %*{
      "range": {
         "start": {"line": 37, "character": 38},
         "end" : {"line": 37, "character": 51}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
wire a_common_wire
```

This is the docstring for `a_common_wire`."""
      }
   })
)


run_test("textDocument/hover: expanded macro in declaration",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 51,
         "character": 9
      }
   }),
   new_lsp_response(230, 15, %*{
      "range": {
         "start": {"line": 51, "character": 9},
         "end" : {"line": 51, "character": 12}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
wire baz = (my_reg & one) || (wider_reg[0] & wider_reg[1])
```"""
      }
   })
)


run_test("textDocument/hover: macro at expansion location",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 45,
         "character": 25
      }
   }),
   new_lsp_response(189, 15, %*{
      "range": {
         "start": {"line": 45, "character": 23},
         "end" : {"line": 45, "character": 37}
      },
      "contents": {
         "kind": "markdown",
         "value": "Logic AND between `x` and `1'b0`."
      }
   })
)


run_test("textDocument/hover: port of external module (1)",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 25,
         "character": 12
      }
   }),
   new_lsp_response(221, 15, %*{
      "range": {
         "start": {"line": 25, "character": 9},
         "end" : {"line": 25, "character": 15}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
output wire data_o
```

The 1-bit data output port."""
      }
   })
)


run_test("textDocument/hover: port of external module (2)",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src3_path),
      },
      "position": {
         "line": 24,
         "character": 34
      }
   }),
   new_lsp_response(240, 15, %*{
      "range": {
         "start": {"line": 24, "character": 34},
         "end" : {"line": 24, "character": 39}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
(* another_attr = "false" *) input wire clk_i
```

The clock input."""
      }
   })
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


run_test("textDocument/hover: parameter port of external module",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 14,
         "character": 10
      }
   }),
   new_lsp_response(189, 15, %*{
      "range": {
         "start": {"line": 14, "character": 9},
         "end" : {"line": 14, "character": 12}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
parameter FOO = 0
```"""
      }
   })
)


run_test("textDocument/hover: port of external module, list of ports (1)",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 16,
         "character": 9
      }
   }),
   new_lsp_response(189, 15, %*{
      "range": {
         "start": {"line": 16, "character": 9},
         "end" : {"line": 16, "character": 14}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
.clk_i(clk_local)
```"""
      }
   })
)


run_test("textDocument/hover: port of external module, list of ports (2)",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src4_path),
      },
      "position": {
         "line": 17,
         "character": 9
      }
   }),
   new_lsp_response(178, 15, %*{
      "range": {
         "start": {"line": 17, "character": 9},
         "end" : {"line": 17, "character": 15}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
data_o
```"""
      }
   })
)


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


run_test("textDocument/hover: function",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 50,
         "character": 22
      }
   }),
   new_lsp_response(234, 15, %*{
      "range": {
         "start": {"line": 50, "character": 22},
         "end" : {"line": 50, "character": 29}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
function add_one(input a)
```

Docstring to function `add_one`."""
      }
   })
)


run_test("textDocument/hover: task",
   new_lsp_request(15, "textDocument/hover", %*{
      "textDocument": {
         "uri": "file://" & expand_filename(src2_path),
      },
      "position": {
         "line": 44,
         "character": 20
      }
   }),
   new_lsp_response(225, 15, %*{
      "range": {
         "start": {"line": 44, "character": 8},
         "end" : {"line": 44, "character": 21}
      },
      "contents": {
         "kind": "markdown",
         "value": """
```verilog
task an_empty_task()
```

Docstring to `an_empty_task`."""
      }
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
