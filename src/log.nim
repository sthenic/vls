import strutils

when not defined(windows):
   proc syslog(priority: cint, msg: cstring) {.importc, header: "<syslog.h>".}

const
   LOG_EMERG = cint(0)
   LOG_ALERT = cint(1)
   LOG_CRIT = cint(2)
   LOG_ERR = cint(3)
   LOG_WARNING = cint(4)
   LOG_NOTICE = cint(5)
   LOG_INFO = cint(6)
   LOG_DEBUG = cint(7)

   LOG_KERN = cint(0 shl 3)
   LOG_USER = cint(1 shl 3)
   LOG_MAIL = cint(2 shl 3)
   LOG_DAEMON = cint(3 shl 3)
   LOG_AUTH = cint(4 shl 3)
   LOG_SYSLOG = cint(5 shl 3)
   LOG_LPR = cint(6 shl 3)
   LOG_NEWS = cint(7 shl 3)
   LOG_UUCP = cint(8 shl 3)
   LOG_CRON = cint(9 shl 3)
   LOG_AUTHPRIV = cint(10 shl 3)
   LOG_FTP = cint(11 shl 3)


type LogTarget* = enum
   STDERR, SYSLOG


var log_target: LogTarget = STDERR


proc set_log_target*(target: LogTarget) =
   log_target = target


template write(header, msg: string, args: varargs[string, `$`]) =
   if log_target == SYSLOG:
      for line in split_lines(format(msg, args)):
         syslog(LOG_INFO or LOG_DAEMON, line)
   else:
      let msg_split = split_lines(format(msg, args))
      write(stderr, header & msg_split[0] & "\n")
      for i in 1..<len(msg_split):
         write(stderr, "         " & msg_split[i] & "\n")


template info*(msg: string, args: varargs[string, `$`]) =
   write("INFO:    ", msg, args)


template warning*(msg: string, args: varargs[string, `$`]) =
   write("WARNING: ", msg, args)


template error*(msg: string, args: varargs[string, `$`]) =
   write("ERROR:   ", msg, args)


template debug_always*(msg: string, args: varargs[string, `$`]) =
   write("DEBUG:   ", msg, args)


template debug*(msg: string, args: varargs[string, `$`]) =
   if defined(logdebug):
      debug_always(msg, args)


template abort*(e: typedesc[Exception], msg: string, args: varargs[string, `$`]) =
   error(msg, args)
   raise new_exception(e, format(msg, args))
