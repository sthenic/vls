import strutils

when not defined(windows):
   proc syslog(priority: cint, msg: cstring) {.importc, header: "<syslog.h>".}

const
   LOG_ERR = cint(3)
   LOG_WARNING = cint(4)
   LOG_INFO = cint(6)
   LOG_DEBUG = cint(7)

   LOG_USER = cint(1 shl 3)


type LogTarget* = enum
   STDERR, SYSLOG


var log_target: LogTarget = STDERR


proc set_log_target*(target: LogTarget) =
   log_target = target


template write_stderr(header, msg: string, args: varargs[string, `$`]) =
   let msg_split = split_lines(format(msg, args))
   write(stderr, header & msg_split[0] & "\n")
   for i in 1..<len(msg_split):
      write(stderr, "         " & msg_split[i] & "\n")


template write_syslog(level: cint, msg: string, args: varargs[string, `$`]) =
   for line in split_lines(format(msg, args)):
      syslog(level or LOG_USER, line)


template write(level: cint, header, msg: string, args: varargs[string, `$`]) =
   when defined(windows):
      write_stderr(header, msg, args)
   else:
      if log_target == SYSLOG:
         write_syslog(level, msg, args)
      else:
         write_stderr(header, msg, args)


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
