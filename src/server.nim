import streams
import strutils
import json
import uri
import tables
import vparse

import ./log
import ./protocol
import ./analyze
import ./source_unit


const
   EOK* = 0
   ENOSHUTDOWN* = 1
   ESTREAM* = 2
   EINVAL* = 3

   VERSION = strip(static_read("./VERSION"))


type
   LspClientCapabilities = object
      diagnostics: bool
      configuration: bool

   LspServer* = object
      ifs, ofs: Stream
      is_initialized: bool
      is_shut_down: bool
      should_exit: bool
      root_uri: string
      source_units: Table[string, SourceUnit]
      cache: IdentifierCache
      client_capabilities: LspClientCapabilities
      # TODO: This should really not be an option if Neovims language client
      #       correctly reported diagnostic capabilities.
      force_diagnostics*: bool


proc init(cc: var LspClientCapabilities) =
   cc.diagnostics = false
   cc.configuration = false


proc open*(s: var LspServer, ifs, ofs : Stream) =
   s.ifs = ifs
   s.ofs = ofs
   s.is_initialized = false
   s.is_shut_down = false
   set_len(s.root_uri, 0)
   s.source_units = init_table[string, SourceUnit](64)
   init(s.client_capabilities)

   # The syslog facilities are only available on Linux and macOS. If the server
   # is compiled in release mode and we're not on Windows, we redirect the log
   # messages to syslog. Otherwise, log messages are written to stderr.
   if defined(release):
      set_log_target(HOMEDIR)
   log.debug("Opened server.")


proc close*(s: var LspServer) =
   # The streams objects are the responsibility of the caller.
   s.is_initialized = false
   s.is_shut_down = false


proc send(s: LspServer, msg: LspMessage) =
   send(s.ofs, msg)


proc recv(s: LspServer): LspMessage =
   result = recv(s.ifs)


proc publish_diagnostics(s: LspServer, unit: SourceUnit) =
   ## Publish diagnostics for the compile unit ``unit``.
   var diagnostics = check_syntax(unit)
   # Limit the maximum number of diagnostic messages if required. Negative
   # values signifies an unlimited number of
   let limit = unit.configuration.max_nof_diagnostics
   log.debug("Max nof diagnostics is $1", limit)
   if limit > 0 and len(diagnostics) > limit:
      log.debug("Limiting the number of diagnostic messages to $1", limit)
      set_len(diagnostics, limit)
   let parameters = %*{
      "uri": construct_uri(unit.filename),
      "diagnostics": diagnostics
   }
   log.debug("Publishing diagnostics: $1", parameters)
   send(s, new_lsp_notification("textDocument/publishDiagnostics", parameters))


proc process_text(s: var LspServer, uri, text: string) =
   ## Create a new source unit from the input ``text``. The environment
   ## (include paths etc.) is initialized from the ``uri``. The resulting
   ## source unit will be indexed with the ``uri`` as key.
   log.debug("Processing text from '$1'.", uri)
   var unit: SourceUnit
   open(unit, get_path_from_uri(uri), text)

   # Index the source unit to be able to analyze the graph when the client
   # makes subsequent request. If an element already exists in the table, we
   # call the close proc before discarding the old source unit in favor of
   # the new.
   if has_key(s.source_units, uri):
      log.debug("Closing source unit for file '$1'.", uri)
      close(s.source_units[uri])
   log.debug("Adding a new source unit for the file '$1' to the index.", uri)
   s.source_units[uri] = unit

   if s.client_capabilities.diagnostics or s.force_diagnostics:
      publish_diagnostics(s, s.source_units[uri])


proc initialize(s: var LspServer, msg: LspMessage) =
   try:
      s.root_uri = get_str(msg.parameters["rootUri"])
      # FIXME: textDocument is optional. We need some Alasso-style descend object thing.
      s.client_capabilities.diagnostics =
         has_key(msg.parameters["capabilities"]["textDocument"], "publishDiagnostics")
      s.client_capabilities.configuration =
         has_key(msg.parameters["capabilities"], "workspace") and
         has_key(msg.parameters["capabilities"]["workspace"], "configuration") and
         get_bool(msg.parameters["capabilities"]["workspace"]["configuration"])

      var result = new_jobject()
      result["serverInfo"] = %*{
         "name": "vls",
         "version": VERSION
      }
      result["capabilities"] = %*{
         "textDocumentSync": 1,
         "declarationProvider": true,
         "definitionProvider": true,
         "referencesProvider": true,
         "completionProvider": {},
         "documentSymbolProvider": true
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


template analyze_text_document(s: LspServer, msg: LspMessage, uri, body: untyped) =
   try:
      let uri = decode_url(validate_string(msg.parameters, ["textDocument", "uri"]))
      if has_key(s.source_units, uri):
         try:
            body
         except AnalyzeError:
            send(s, new_lsp_response(msg.id, new_jnull()))
      else:
         send(s, new_lsp_response(msg.id, RPC_INTERNAL_ERROR, format("File '$1' is not in the index.", uri), nil))
   except LspParseError as e:
      send(s, new_lsp_response(msg.id, RPC_PARSE_ERROR, e.msg, nil))


template analyze_text_document_position(s: LspServer, msg: LspMessage, uri, line, col, body: untyped) =
   analyze_text_document(s, msg, uri):
      let line = validate_int(msg.parameters, ["position", "line"])
      let col = validate_int(msg.parameters, ["position", "character"])
      body


proc declaration(s: LspServer, msg: LspMessage) =
   analyze_text_document_position(s, msg, uri, line, col):
      let location = find_declaration(s.source_units[uri], line + 1, col)
      send(s, new_lsp_response(msg.id, %[location]))


proc references(s: LspServer, msg: LspMessage) =
   analyze_text_document_position(s, msg, uri, line, col):
      let include_declaration = validate_bool(msg.parameters, ["context", "includeDeclaration"])
      let locations = find_references(s.source_units[uri], line + 1, col, include_declaration)
      send(s, new_lsp_response(msg.id, %locations))


proc completion(s: LspServer, msg: LspMessage) =
   analyze_text_document_position(s, msg, uri, line, col):
      # FIXME: Ignore the completion context for now.
      let completion_items = find_completions(s.source_units[uri], line + 1, col)
      send(s, new_lsp_response(msg.id, %completion_items))


proc document_symbol(s: LspServer, msg: LspMessage) =
   analyze_text_document(s, msg, uri):
      let symbols = find_symbols(s.source_units[uri])
      send(s, new_lsp_response(msg.id, %symbols))


proc handle_request(s: var LspServer, msg: LspMessage) =
   # If the server is shut down we respond to every request with an error.
   # Otherwise, unless the server is initialized, we only respond to the
   # 'initialize' request.
   log.debug("Handling a request: '$1'.", msg.m)
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
   of "textDocument/declaration":
      declaration(s, msg)
   of "textDocument/definition":
      # TODO: Figure out if this is good enough.
      declaration(s, msg)
   of "textDocument/references":
      references(s, msg)
   of "textDocument/completion":
      completion(s, msg)
   of "textDocument/documentSymbol":
      document_symbol(s, msg)
   else:
      let str = format("Unsupported method '$1'.", msg.m)
      send(s, new_lsp_response(msg.id, RPC_INVALID_REQUEST, str, nil))


proc initialized(s: LspServer) =
   # Handles the 'initialized' notification sent from the language client. We
   # use this to register for dynamic events.
   if s.client_capabilities.configuration:
      send(s, new_lsp_request(0, "client/registerCapability", %*{
         "registrations": [
            {
               "id": "workspace/didChangeConfiguration",
               "method": "workspace/didChangeConfiguration"
            }
         ]
      }))


proc workspace_changed_configuration(s: var LspServer) =
   # Request the 'vls' section from the client configuration.
   log.debug("Requesting workspace configuration.")
   send(s, new_lsp_request(0, "workspace/configuration", %*{
      "items": [
         {"section": "vls"}
      ]
   }))
   let response = recv(s)
   # FIXME: Use the settings.
   log.debug("Got configuration $1", response)


proc handle_notification(s: var LspServer, msg: LspMessage) =
   # If the server is not initialized, all notifications should be dropped,
   # except for the exit notification.
   log.debug("Handling a notification: '$1'.", msg.m)
   if msg.m == "exit":
      s.should_exit = true
      return
   elif not s.is_initialized:
      return

   case msg.m
   of "initialized":
      initialized(s)
   of "workspace/didChangeConfiguration":
      workspace_changed_configuration(s)
   of "textDocument/didOpen":
      let uri = decode_url(get_str(msg.parameters["textDocument"]["uri"]))
      let text = get_str(msg.parameters["textDocument"]["text"])
      process_text(s, uri, text)
   of "textDocument/didChange":
      # We can read all the changes at array index 0 since we only support the
      # 'full' text synchronization.
      let uri = decode_url(get_str(msg.parameters["textDocument"]["uri"]))
      let text = get_str(msg.parameters["contentChanges"][0]["text"])
      process_text(s, uri, text)
   of "textDocument/didClose":
      let uri = decode_url(get_str(msg.parameters["textDocument"]["uri"]))
      if has_key(s.source_units, uri):
         log.debug("Closing source unit for file '$1'.", uri)
         close(s.source_units[uri])
         del(s.source_units, uri)
   else:
      # Simply drop all other notifications.
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
      of MkResponseSuccess, MkResponseError:
         # FIXME: Check if we're expecintg a response to come through.
         log.debug("Received a response $1", msg)
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
