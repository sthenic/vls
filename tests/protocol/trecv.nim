import streams
import terminal
import strformat
import strutils
import json

import ../../src/protocol

var nof_passed = 0
var nof_failed = 0

template run_test(title, stimuli: string, reference: LspMessage, expect_error = false) =
   try:
      let response = recv(new_string_stream(stimuli))
      if response == reference:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         echo response
         echo reference
   except LspParseError as e:
      if expect_error:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         echo e.msg


proc add_headers(content: string): string =
   result = format("Content-Length: $1\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n$2", len(content), content)


# Test suite title
styledWriteLine(stdout, styleBright,
"""

Test suite: receive
-------------------""")


# Test cases
run_test("Missing Content-Length header", "\r\n", LspMessage(), true)


run_test("Invalid Content-Type", """
Content-Length: 0
Content-Type: foo""", LspMessage(), true)


var reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "method": ""
}""")
run_test("Request: no parameters", reference): new_lsp_request(
   52, 0, "", nil
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "method": "",
   "params": {}
}""")
run_test("Request: empty JSON object", reference): new_lsp_request(
   69, 0, "", %*{}
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "method": "",
   "params": []
}""")
run_test("Request: empty JSON array", reference): new_lsp_request(
   69, 0, "", %*[]
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "method": "",
   "params": 89
}""")
run_test("Request: invalid type for 'params'", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "method": 2
}""")
run_test("Request: invalid type for 'method'", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "method": "textDocument/didSave"
}""")
run_test("Request: method", reference): new_lsp_request(
   72, 0, "textDocument/didSave", nil
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "result": {}
}""")
run_test("Response success: empty result", reference): new_lsp_response(
   52, 0, %*{}
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "result": [1, 2, 3]
}""")
run_test("Response success: array result", reference): new_lsp_response(
   59, 0, %*[1, 2, 3]
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "result": [1, 2, 3],
   "error": {}
}""")
run_test("Response error & result present -> error", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0
}""")
run_test("Response error & result missing -> error", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "error": {
   }
}""")
run_test("Response error: missing code", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "error": {
      "code": -32700
   }
}""")
run_test("Response error: missing message", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "error": {
      "code": -32700,
      "message": "An error!"
   }
}""")
run_test("Response error: w/o data", reference): new_lsp_response(
   106, 0, RPC_PARSE_ERROR, "An error!", nil
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": 0,
   "error": {
      "code": -32700,
      "message": "An error!",
      "data": [
         "foo", "bar", "baz"
      ]
   }
}""")
run_test("Response error: w/ data", reference): new_lsp_response(
   160, 0, RPC_PARSE_ERROR, "An error!", %*["foo", "bar", "baz"]
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": "1",
   "method": ""
}""")
run_test("Id as a string", reference): new_lsp_request(
   54, 1, "", nil
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "id": "foo",
   "method": ""
}""")
run_test("Invalid id", reference, LspMessage(), true)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "method": "$/cancelRequest"
}""")
run_test("Notification w/o parameters", reference): new_lsp_notification(
   55, "$/cancelRequest", nil
)


reference = add_headers("""{
   "jsonrpc": "2.0",
   "method": "$/cancelRequest",
   "params": [1, 2, 3]
}""")
run_test("Notification w/ parameters", reference): new_lsp_notification(
   79, "$/cancelRequest", %*[1, 2, 3]
)


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
