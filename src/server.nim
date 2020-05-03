import streams
import strutils
import json
import uri
import vparse

import ./protocol
import ./analyze
import ./log


const
   EOK = 0
   ENOSHUTDOWN = 1
   ESTREAM = 2


type
   LspClientCapabilities = object
      diagnostics: bool

   LspServer* = object
      ifs, ofs: Stream
      is_initialized: bool
      is_shut_down: bool
      should_exit: bool
      root_uri: string
      graph_uri: string
      graph: Graph
      cache: IdentifierCache
      client_capabilities: LspClientCapabilities


proc init(cc: var LspClientCapabilities) =
   cc.diagnostics = false


proc open*(s: var LspServer, ifs, ofs : Stream) =
   s.ifs = ifs
   s.ofs = ofs
   s.is_initialized = false
   s.is_shut_down = false
   set_len(s.root_uri, 0)
   set_len(s.graph_uri, 0)
   init(s.client_capabilities)

   # The syslog facilities are only available on Linux and macOS. If the server
   # is compiled in release mode and we're not on Windows, we redirect the log
   # messages to syslog. Otherwise, log messages are written to stderr.
   if defined(release) and not defined(windows):
      set_log_target(SYSLOG)
   log.debug("Opened server.")


proc close*(s: var LspServer) =
   # The streams objects are the responsibility of the caller.
   s.is_initialized = false
   s.is_shut_down = false


proc send(s: LspServer, msg: LspMessage) =
   send(s.ofs, msg)


proc recv(s: LspServer): LspMessage =
   result = recv(s.ifs)


proc initialize(s: var LspServer, msg: LspMessage) =
   try:
      s.root_uri = get_str(msg.parameters["rootUri"])
      # FIXME: textDocument is optional. We need some Alasso-style descend object thing.
      s.client_capabilities.diagnostics =
         has_key(msg.parameters["capabilities"]["textDocument"], "publishDiagnostics")

      var result = new_jobject()
      result["serverInfo"] = %*{
         "name": "vls",
         # FIXME: Read this from a shared static location.
         "version": "0.1.0"
      }
      result["capabilities"] = %*{
         "textDocumentSync": 1
      }
      send(s, new_lsp_response(msg.id, result))
      s.is_initialized = true
      log.debug("Server initialized.")
      log.debug("Client capabilities: $1.", s.client_capabilities)

   except KeyError as e:
      send(s, new_lsp_response(msg.id, RPC_PARSE_ERROR, e.msg, nil))


proc shutdown(s: var LspServer, msg: LspMessage) =
   log.debug("Server shutting down.")
   s.is_shut_down = true
   send(s, new_lsp_response(msg.id, new_jnull()))


proc handle_request(s: var LspServer, msg: LspMessage) =
   # If the server is shut down we respond to every request with an error.
   # Otherwise, unless the server is initialized, we only respond to the
   # 'initialize' request.
   log.debug("Handling a request.")
   if s.is_shut_down:
      send(s, new_lsp_response(msg.id, RPC_INVALID_REQUEST, "", nil))
      return
   elif not s.is_initialized:
      if msg.m == "initialize":
         initialize(s, msg)
      else:
         send(s, new_lsp_response(msg.id, RPC_SERVER_NOT_INITIALIZED, "", nil))
      return

   case msg.m
   of "shutdown":
      shutdown(s, msg)
   else:
      let str = format("Unsupported method '$1'.", msg.m)
      send(s, new_lsp_response(msg.id, RPC_INVALID_REQUEST, str, nil))


proc handle_notification(s: var LspServer, msg: LspMessage) =
   # If the server is not initialized, all notifications should be dropped,
   # except for the exit notification.
   log.debug("Handling a notification.")
   if msg.m == "exit":
      s.should_exit = true
      return
   elif not s.is_initialized:
      return

   # FIXME: Generalize to handle multiple files.
   # FIXME: Generalize into proc.
   case msg.m
   of "textDocument/didOpen":
      s.cache = new_ident_cache()
      s.graph_uri = get_str(msg.parameters["textDocument"]["uri"])
      let contents = get_str(msg.parameters["textDocument"]["text"])
      let ss = new_string_stream(contents)
      log.debug("Opening a graph for $1.", s.graph_uri)
      open_graph(s.graph, s.cache, ss, parse_uri(s.graph_uri).path, [], [])
      close(ss)
      log.debug("Analyzing the AST.")
      let has_errors = check_syntax(s.graph.root_node)
      log.debug("The AST $1", if has_errors: "has errors." else: "is ok.")
   of "textDocument/didChange":
      close_graph(s.graph)
      # We can read all the changes at array index 0 since we only support the
      # 'full' text synchronization.
      s.graph_uri = get_str(msg.parameters["textDocument"]["uri"])
      let contents = get_str(msg.parameters["contentChanges"][0]["text"])
      let ss = new_string_stream(contents)
      log.debug("Refreshing graph for $1.", s.graph_uri)
      open_graph(s.graph, s.cache, ss, parse_uri(s.graph_uri).path, [], [])
      close(ss)
      log.debug("Analyzing the AST.")
      let has_errors = check_syntax(s.graph.root_node)
      log.debug("The AST $1", if has_errors: "has errors." else: "is ok.")
   else:
      # Simply drop all other request.
      discard


proc run*(s: var LspServer): int =
   while true:
      # Receive a message from the input stream.
      log.debug("Waiting for an LSP message.")
      let msg =
         try:
            recv(s)
         except LspIoError as e:
            send(s, new_lsp_response(0, RPC_INTERNAL_ERROR, e.msg, nil))
            return -ESTREAM
         except LspParseError as e:
            send(s, new_lsp_response(0, RPC_PARSE_ERROR, e.msg, nil))
            continue
      log.debug("Received an LSP message, length $1.", msg.length)

      # Handle the message. We protect against exceptions
      case msg.kind
      of MkRequest:
         try:
            handle_request(s, msg)
         except Exception as e:
            let error_message = "Uncaught exception when handling request: " & e.msg
            log.error(error_message)
            send(s, new_lsp_response(msg.id, RPC_INTERNAL_ERROR, error_message, nil))
      of MkNotification:
         try:
            handle_notification(s, msg)
         except Exception as e:
            log.error("Uncaught exception when handling notification: " & e.msg)
      else:
         send(s, new_lsp_response(msg.id, RPC_INVALID_REQUEST, "", nil))

      # Check if we have been instructed to shut down the server.
      if s.should_exit:
         if s.is_shut_down:
            result = EOK
         else:
            result = ENOSHUTDOWN
         log.debug("Server exiting, exit code $1.", result)
         break
