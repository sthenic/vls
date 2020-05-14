import terminal
import strformat
import os

import ../../src/configuration

var nof_passed = 0
var nof_failed = 0

template run_test(title, stimuli: string, reference: Configuration, expect_error = false) =
   try:
      let response = parse_string(stimuli)
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
   except ConfigurationParseError as e:
      if expect_error:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         echo e.msg


template run_test_file(title, filename: string, reference: Configuration, expect_error = false) =
   try:
      let response = parse_file(filename)
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
   except ConfigurationParseError as e:
      if expect_error:
         styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_passed)
      else:
         styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                        fgWhite, "Test '",  title, "'")
         inc(nof_failed)
         echo e.msg


template run_test_find_file(title, stimuli, reference: string) =
   let response = find_configuration_file(stimuli)
   if response == expand_filename(reference):
      styledWriteLine(stdout, styleBright, fgGreen, "[✓] ",
                     fgWhite, "Test '",  title, "'")
      inc(nof_passed)
   else:
      styledWriteLine(stdout, styleBright, fgRed, "[✗] ",
                     fgWhite, "Test '",  title, "'")
      inc(nof_failed)
      echo response
      echo reference


proc new_configuration(max_nof_diagnostics: int, include_paths, defines: seq[string]): Configuration =
   result.include_paths = include_paths
   result.defines = defines
   result.max_nof_diagnostics = max_nof_diagnostics


run_test("verilog.include_paths", """
[verilog]
include_paths = [
    "/path/to/some/directory",
    "/path/to/another/directory",
    "../a/relative/path"
]
""", new_configuration(-1, @[
    "/path/to/some/directory",
    "/path/to/another/directory",
    "../a/relative/path"
], @[]))

run_test("verilog.defines", """
[verilog]
defines = [
    "FOO",
    "WIDTH=8",
    "ONES(x) = {(x){1'b1}}"
]""", new_configuration(-1, @[], @[
    "FOO",
    "WIDTH=8",
    "ONES(x) = {(x){1'b1}}"
]))


run_test("Parse error: invalid TOML", """
include_paths = [
    "An open string literal
]""", Configuration(), true)


run_test("Parse error: 'verilog.include_paths' is not an array", """
[verilog]
include_paths = "a simple string"
""", Configuration(), true)


run_test("Parse error: 'verilog.include_paths' is not an array of strings", """
[verilog]
include_paths = [1, 2, 3]
""", Configuration(), true)


run_test("Parse error: 'verilog.defines' is not an array", """
[verilog]
defines = 3.1459
""", Configuration(), true)


run_test("Parse error: 'verilog.defines' is not an array of strings", """
[verilog]
defines = [true, false]
""", Configuration(), true)


run_test_file("Parse from a file (trim whitespace)", "cfg.toml",
   new_configuration(-1, @[
      "/path/to/some/directory",
      "/path/to/another/directory",
      join_path(expand_filename("."), "../a/relative/path")
   ], @[
      "FOO",
      "WIDTH=8",
      "ONES(x) = {(x){1'b1}}"
   ])
)


run_test_file("Parse error: the file does not exist", "foo.toml", Configuration(), true)


run_test_find_file("Find '.vls.toml'.", "./", "./.vls/vls.toml")


run_test("vls.max_nof_diagnostics", """
[vls]
max_nof_diagnostics = 10
""", new_configuration(10, @[], @[]))


run_test("Parse error: 'vls.max_nof_diagnostics' is not an integer", """
[vls]
max_nof_diagnostics = "foo"
""", Configuration(), true)


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
