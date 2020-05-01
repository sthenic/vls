import streams
import terminal
import strformat
import strutils

import ../../src/protocol

var nof_passed = 0
var nof_failed = 0

template run_test(title: string, stimuli: LspMessage, reference: string, expect_error = false) =
   try:
      var ss = new_string_stream()
      send_response(ss, stimuli)
      set_position(ss, 0)
      var response = read_all(ss)

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


proc prepare_header(length: int): string =
   result = format("Content-Length: $1\r\nContent-Type: application/vscode-jsonrpc; charset=utf-8\r\n\r\n", length)

#
# Test cases
#
var response = new_lsp_response(0, %*{
   "foo": "bar"
})
run_test("Test success (object)", response, prepare_header(47) & $parse_json("""
{
   "jsonrpc": "2.0",
   "id": 0,
   "result": {"foo": "bar"}
}"""))


response = new_lsp_response(10, RPC_PARSE_ERROR, "Something went wrong.", %*{})
run_test("Test error (data is a JSON object)", response, prepare_header(93) & $parse_json("""
{
   "jsonrpc": "2.0",
   "id": 10,
   "error": {
      "code": -32700,
      "message": "Something went wrong.",
      "data": {}
   }
}"""))


response = new_lsp_response(2, RPC_PARSE_ERROR, "Something went wrong.", nil)
run_test("Test error (no data)", response, prepare_header(82) & $parse_json("""
{
   "jsonrpc": "2.0",
   "id": 2,
   "error": {
      "code": -32700,
      "message": "Something went wrong."
   }
}"""))



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
