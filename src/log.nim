import strutils
import streams
import os


when not defined(windows):
   proc syslog(priority: cint, msg: cstring) {.importc, header: "<syslog.h>".}


const
   LOG_ERR = cint(3)
   LOG_WARNING = cint(4)
   LOG_INFO = cint(6)
   LOG_DEBUG = cint(7)

   LOG_USER = cint(1 shl 3)


type LogTarget* = enum
   STDERR, SYSLOG, HOMEDIR


var log_target: LogTarget = STDERR
var log_stream: FileStream


template write_stderr(header, msg: string, args: varargs[string, `$`]) =
   let msg_split = split_lines(format(msg, args))
   write(stderr, header & msg_split[0] & "\n")
   for i in 1..<len(msg_split):
      write(stderr, "         " & msg_split[i] & "\n")


proc set_log_target*(target: LogTarget) =
   log_target = target
   if target == HOMEDIR:
      let path = get_home_dir() / ".vls"
      try:
         create_dir(path)
         let filename = path / "vls.log"
         log_stream = new_file_stream(filename, fmWrite)
         if log_stream == nil:
            write_stderr("Failed to open file '$1'. Log messages will be written to stderr.", path)
            log_target = STDERR
      except OSError:
         write_stderr("Failed to create path '$1'. Log messages will be written to stderr.", path)
         log_target = STDERR


template write_homedir(header, msg: string, args: varargs[string, `$`]) =
   let msg_split = split_lines(format(msg, args))
   write(log_stream, header & msg_split[0] & "\n")
   for i in 1..<len(msg_split):
      write(log_stream, "         " & msg_split[i] & "\n")
   flush(log_stream)


template write_syslog(level: cint, msg: string, args: varargs[string, `$`]) =
   for line in split_lines(format(msg, args)):
      syslog(level or LOG_USER, line)


template write(level: cint, header, msg: string, args: varargs[string, `$`]) =
   when defined(windows):
      case log_target
      of STDERR, SYSLOG:
         write_stderr(header, msg, args)
      of HOMEDIR:
         write_homedir(header, msg, args)
   else:
      case log_target
      of STDERR:
         write_stderr(header, msg, args)
      of SYSLOG:
         write_syslog(level, msg, args)
      of HOMEDIR:
         write_homedir(header, msg, args)


template info*(msg: string, args: varargs[string, `$`]) =
   write(LOG_INFO, "INFO:    ", msg, args)


template warning*(msg: string, args: varargs[string, `$`]) =
   write(LOG_WARNING, "WARNING: ", msg, args)


template error*(msg: string, args: varargs[string, `$`]) =
   write(LOG_ERR, "ERROR:   ", msg, args)


template debug_always*(msg: string, args: varargs[string, `$`]) =
   write(LOG_DEBUG, "DEBUG:   ", msg, args)


template debug*(msg: string, args: varargs[string, `$`]) =
   if defined(logdebug):
      debug_always(msg, args)


template abort*(e: typedesc[Exception], msg: string, args: varargs[string, `$`]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
