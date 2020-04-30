import streams
import strutils

import ./protocol

const
   EOK = 0
   ESTREAM = 1

var ofs: FileStream
var ifs: FileStream

try:
   ofs = new_file_stream(stdout)
   ifs = new_file_stream(stdin)
except IOError:
   quit(-ESTREAM)


while true:
   let req =
      try:
         get_request(ifs)
      except RequestIoError as e:
         write_line(ofs, format("Error: $1", e.msg))
         quit(-ESTREAM)
      except RequestValueError as e:
         write_line(ofs, format("Error: $1", e.msg))
         continue

   write_line(ofs, pretty(req.parameters))

quit(EOK)
