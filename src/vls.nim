import streams
import strutils

import ./server
import ./cli

const
   VERSION_STR = strip(static_read("./VERSION"))
   STATIC_HELP_TEXT = strip(static_read("./CLI_HELP"))

let HELP_TEXT = "vls v" & VERSION_STR & "\n\n" & STATIC_HELP_TEXT

let cli_state =
   try:
      parse_cli()
   except CliValueError:
      quit(EINVAL)

if cli_state.print_help:
   echo HELP_TEXT
   quit(EOK)
elif cli_state.print_version:
   echo VERSION_STR
   quit(EOK)


var s: LspServer
s.force_diagnostics = cli_state.force_diagnostics
s.force_configuration_file = cli_state.force_configuration_file
open(s, new_file_stream(stdin), new_file_stream(stdout))
let exit_code = run(s)
close(s)
quit(exit_code)
