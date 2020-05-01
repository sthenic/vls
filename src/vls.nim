import streams
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
         send_response(ofs, new_lsp_response(0, RPC_INTERNAL_ERROR, e.msg, nil))
         quit(-ESTREAM)
      except LspParseError as e:
         send_response(ofs, new_lsp_response(0, RPC_PARSE_ERROR, e.msg, nil))
         continue

   write_line(ofs, pretty(req.parameters))

quit(EOK)
