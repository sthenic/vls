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
         recv_request(ifs)
      except LspIoError as e:
         write_line(ofs, format("Error: $1", e.msg))
         quit(-ESTREAM)
      except LspParseError as e:
         send_response(ofs, new_lsp_error_response(0, RPC_PARSE_ERROR, e.msg, nil))
         continue

   write_line(ofs, pretty(req.parameters))

quit(EOK)
