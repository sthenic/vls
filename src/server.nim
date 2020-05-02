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
      root_uri: string


proc open*(s: var LspServer, ifs, ofs : Stream) =
   s.ifs = ifs
   s.ofs = ofs
   s.is_initialized = false


proc close*(s: var LspServer) =
   close(s.ifs)
   close(s.ofs)


proc initialize(s: var LspServer, msg: LspMessage) =
   try:
      s.root_uri = get_str(msg.parameters["rootUri"])

      var parameters = new_jobject()
      parameters["serverInfo"] = %*{
         "name": "vls",
         # FIXME: Read this from a shared static location.
         "version": "0.1.0"
      }
      parameters["capabilities"] = %*{
         "textDocument": {
            "declaration": {
               "dynamicRegistration": false,
               "linkSupport": false
            }
         }
      }
      send_response(s.ofs, new_lsp_response(msg.id, parameters))

   except KeyError as e:
      send_response(s.ofs, new_lsp_response(msg.id, RPC_PARSE_ERROR, e.msg, nil))


proc handle_request(s: var LspServer, msg: LspMessage) =
   # If the server is not initialized, we only respond to the 'initialize'
   # request.
   if not s.is_initialized:
      if msg.m == "initialize":
         initialize(s, msg)
      else:
         send_response(s.ofs, new_lsp_response(msg.id, RPC_SERVER_NOT_INITIALIZED, "", nil))
      return

   let str = format("Unsupported method '$1'.", msg.m)
   send_response(s.ofs, new_lsp_response(msg.id, RPC_METHOD_NOT_FOUND, str, nil))


proc handle_notification(s: LspServer, msg: LspMessage) =
   # If the server is not initialized, all notifications should be dropped,
   # except for the exit notification.
   if not s.is_initialized:
      return


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

      # Handle the message.
      case msg.kind
      of MkRequest:
         handle_request(s, msg)
      of MkNotification:
         handle_notification(s, msg)
      else:
         send_response(s.ofs, new_lsp_response(msg.id, RPC_INVALID_REQUEST, "", nil))

   result = EOK
