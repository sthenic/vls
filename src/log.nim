import strutils
import terminal
import macros

import ./wordwrap

type ColorMode* = enum
   Color, NoColor


const
   INFO_COLOR = fgBlue
   WARNING_COLOR = fgYellow
   ERROR_COLOR = fgRed
   DEBUG_COLOR = fgMagenta


var quiet_mode = false
var color_mode = Color


proc set_quiet_mode*(state: bool) =
   quiet_mode = state


proc set_color_mode*(mode: ColorMode) =
   color_mode = mode


macro call_styled_write_line_internal_nocolor(args: varargs[typed]): untyped =
   proc unpack_args(p: NimNode, n: NimNode) {.compiletime.} =
      for c in children(n):
         if c.kind == nnkHiddenStdConv:
            p.unpack_args(c[1])
         elif not(sameType(getType(terminal.Style), c.getType) or
                  sameType(getType(terminal.ForegroundColor), c.getType) or
                  sameType(getType(terminal.BackgroundColor), c.getType) or
                  sameType(getType(terminal.TerminalCmd), c.getType)):
            # Avoid adding nodes with the 'terminal' package style
            # types are added.
            p.add(c)

   result = newCall(bindSym"echo")
   result.unpack_args(args)


macro call_styled_write_line_internal(args: varargs[typed]): untyped =
   proc unpack_args(p: NimNode, n: NimNode) {.compiletime.} =
      for c in children(n):
         if c.kind == nnkHiddenStdConv:
            p.unpack_args(c[1])
         else:
            p.add(c)

   result = newCall(bindSym"styledWriteLine")
   result.add(bindSym"stdout")
   result.unpack_args(args)


template call_styled_write_line*(args: varargs[typed]) =
   case color_mode
   of Color:
      call_styled_write_line_internal(args)
   of NoColor:
      call_styled_write_line_internal_nocolor(args)


template info*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, INFO_COLOR, "INFO:    ",
                             resetStyle, args)


template info*(msg: string, args: varargs[string, `$`]) =
   if not quiet_mode:
      let msg_split = wrap_words(format(msg, args), 80, true).split_lines()
      call_styled_write_line(styleBright, INFO_COLOR, "INFO:    ",
                             resetStyle, msg_split[0])
      for m in 1..<len(msg_split):
         call_styled_write_line("         " & msg_split[m])


template warning*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, WARNING_COLOR, "WARNING: ",
                             resetStyle, args)


template warning*(msg: string, args: varargs[string, `$`]) =
   if not quiet_mode:
      let msg_split = wrap_words(format(msg, args), 80, true).split_lines()
      call_styled_write_line(styleBright, WARNING_COLOR, "WARNING: ",
                             resetStyle, msg_split[0])
      for m in 1..<len(msg_split):
         call_styled_write_line("         " & msg_split[m])


template error*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, ERROR_COLOR, "ERROR:   ",
                             resetStyle, args)


template error*(msg: string, args: varargs[string, `$`]) =
   if not quiet_mode:
      let msg_split = wrap_words(format(msg, args), 80, true).split_lines()
      call_styled_write_line(styleBright, ERROR_COLOR, "ERROR:   ",
                             resetStyle, msg_split[0])
      for m in 1..<len(msg_split):
         call_styled_write_line("         " & msg_split[m])


template debug*(args: varargs[typed]) =
   when not defined(release):
      debug_always(args)


template debug*(msg: string, args: varargs[string, `$`]) =
   when not defined(release):
      debug_always(msg, args)


template debug_always*(args: varargs[typed]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, DEBUG_COLOR, "DEBUG:   ",
                             resetStyle, args)


template debug_always*(msg: string, args: varargs[string, `$`]) =
   if not quiet_mode:
      call_styled_write_line(styleBright, DEBUG_COLOR, "DEBUG:   ",
                             resetStyle, format(msg, args))


template abort*(e: typedesc[Exception], msg: string, args: varargs[string, `$`]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
