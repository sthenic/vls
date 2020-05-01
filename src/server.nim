import streams
import strutils
import ./protocol

const
   EOK = 0
   ESTREAM = 1


type
   LspServer* = object
      ifs, ofs: Stream
      is_initialized: bool


proc open*(s: var LspServer, ifs, ofs : Stream) =
   s.ifs = ifs
   s.ofs = ofs
   s.is_initialized = false


proc close*(s: var LspServer) =
   close(s.ifs)
   close(s.ofs)


proc handle_request(s: var LspServer, msg: LspMessage) =
   case msg.m
   of "initialize":
      s.is_initialized = true
   else:
      let str = format("Unsupported method '$1'.", msg.m)
      send_response(s.ofs, new_lsp_response(msg.id, RPC_METHOD_NOT_FOUND, str, nil))


proc handle_notification(s: LspServer, msg: LspMessage) =
   discard


proc run*(s: var LspServer): int =
   while true:
      # Receive a message from the input stream.
      let msg =
         try:
            recv_request(s.ifs)
         except LspIoError as e:
            send_response(s.ofs, new_lsp_response(0, RPC_INTERNAL_ERROR, e.msg, nil))
            return -ESTREAM
         except LspParseError as e:
            send_response(s.ofs, new_lsp_response(0, RPC_PARSE_ERROR, e.msg, nil))
            continue

      case msg.kind
      of MkRequest:
         handle_request(s, msg)
      of MkNotification:
         handle_notification(s, msg)
      else:
         send_response(s.ofs, new_lsp_response(msg.id, RPC_INVALID_REQUEST, "", nil))
         continue

   result = EOK
