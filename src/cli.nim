import parseopt
import strutils

import ./log

type
   CliValueError* = object of ValueError
   CliState* = object
      print_help*: bool
      print_version*: bool
      force_diagnostics*: bool


proc parse_cli*(): CliState =
   var p = init_opt_parser()
   for kind, key, val in p.getopt():
      case kind:
      of cmdArgument:
         log.warning("Unexpected argument '$1'.", key)
      of cmdLongOption, cmdShortOption:
         case key:
         of "help", "h":
            result.print_help = true
         of "version", "v":
            result.print_version = true
         of "force-diagnostics":
            result.force_diagnostics = true
         else:
            log.abort(CliValueError, "Unknown option '$1'.", key)

      of cmdEnd:
         log.abort(CliValueError, "Failed to parse options and arguments. " &
                                  "This should not have happened.")
