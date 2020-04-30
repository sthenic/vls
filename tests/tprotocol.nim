import streams
import terminal
import strformat

import ../src/protocol

var nof_passed = 0
var nof_failed = 0

template run_test(title, stimuli: string, reference: Request, expect_error = false) =
   try:
      let response = get_request(new_string_stream(stimuli))
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
   except RequestValueError as e:
      if expect_error:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         echo e.msg


run_test("Missing Content-Length header", "\r\n", Request(), true)


run_test("Invalid Content-Type", """
Content-Length: 2
Content-Type: foo

{}
""", Request(), true)


run_test("Content-Type", """
Content-Length: 2
Content-Type: application/vscode-jsonrpc; charset=utf-8

{}
""", Request())


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
