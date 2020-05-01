import streams
import terminal
import strformat
import strutils

import ../../src/protocol

var nof_passed = 0
var nof_failed = 0

template run_test(title, stimuli: string, reference: Request, expect_error = false) =
   try:
      let response = recv_request(new_string_stream(stimuli))
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
   except RequestParseError as e:
      if expect_error:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         echo e.msg


proc new_request(length, id: int, m: string, parameters: JsonNode): Request =
   result = Request(length: length, id: id, m: m, parameters: parameters)


proc prepare_stimuli(id, m, parameters: string): string =
   var content = format("""
{
   "jsonrpc": "2.0",
   "id": $1,
   "method": "$2"""", id, m)

   if len(parameters) > 0:
      add(content, format(""",
   "params": $1
}""", parameters))
   else:
      add(content, "\n}")

   result = format("""
Content-Length: $1
Content-Type: application/vscode-jsonrpc; charset=utf-8

$2
""", len(content), content)


proc prepare_stimuli(id: int, m, parameters: string): string =
   result = prepare_stimuli($id, m, parameters)

#
# Test cases
#
run_test("Missing Content-Length header", "\r\n", Request(), true)


run_test("Invalid Content-Type", """
Content-Length: 0
Content-Type: foo""", Request(), true)


var reference = prepare_stimuli(0, "", "")
run_test("No parameters", reference): new_request(
   52, 0, "", nil
)


reference = prepare_stimuli(0, "", "{}")
run_test("Empty JSON object", reference): new_request(
   69, 0, "", %*{}
)


reference = prepare_stimuli(0, "", "[]")
run_test("Empty JSON array", reference): new_request(
   69, 0, "", %*[]
)


reference = prepare_stimuli(0, "textDocument/didSave", "")
run_test("Method", reference): new_request(
   72, 0, "textDocument/didSave", nil
)


reference = prepare_stimuli("\"1\"", "", "")
run_test("Id as a string", reference): new_request(
   54, 1, "", nil
)


reference = prepare_stimuli("\"foo\"", "", "")
run_test("Invalid id", reference, Request(), true)


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
