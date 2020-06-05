import streams
import strutils
import json
import uri
import tables
import vparse

import ./log
import ./protocol
import ./analyze
import ./configuration


const
   EOK* = 0
   ENOSHUTDOWN* = 1
   ESTREAM* = 2
   EINVAL* = 3

   VERSION = strip(static_read("./VERSION"))


type
   CompileUnit = object
      uri: string
      cache: IdentifierCache
      graph: Graph
      configuration: Configuration

   LspClientCapabilities = object
      diagnostics: bool
      configuration: bool

   LspServer* = object
      ifs, ofs: Stream
      is_initialized: bool
      is_shut_down: bool
      should_exit: bool
      root_uri: string
      compile_units: Table[string, CompileUnit]
      cache: IdentifierCache
      client_capabilities: LspClientCapabilities
      # TODO: This should really not be an option if Neovims language client
      #       correctly reported diagnostic capabilities.
      force_diagnostics*: bool


template get_path_from_uri(uri: string): string =
   # On Windows, the uri will look like "file:///c:/path/to/some/file" and the
   # path part is "/c:/path/to/some/file". The leading '/' needs to be removed
   # in order for the path to be valid.
   when defined(windows):
      strip(parse_uri(uri).path, leading = true, trailing = false, {'/'})
   else:
      parse_uri(uri).path


proc close(unit: var CompileUnit) =
   close_graph(unit.graph)


proc init(cc: var LspClientCapabilities) =
   cc.diagnostics = false
   cc.configuration = false


proc open*(s: var LspServer, ifs, ofs : Stream) =
   s.ifs = ifs
   s.ofs = ofs
   s.is_initialized = false
   s.is_shut_down = false
   set_len(s.root_uri, 0)
   s.compile_units = init_table[string, CompileUnit](64)
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


proc publish_diagnostics(s: LspServer, unit: CompileUnit) =
   ## Publish diagnostics for the compile unit ``unit``.
   var diagnostics = check_syntax(unit.graph.root_node, unit.graph.locations)
   # Limit the maximum number of diagnostic messages if required. Negative
   # values signifies an unlimited number of
   let limit = unit.configuration.max_nof_diagnostics
   log.debug("Max nof diagnostics is $1", limit)
   if limit > 0 and len(diagnostics) > limit:
      log.debug("Limiting the number of diagnostic messages to $1", limit)
      set_len(diagnostics, limit)
   let parameters = %*{
      "uri": unit.uri,
      "diagnostics": diagnostics
   }
   log.debug("Publishing diagnostics: $1", parameters)
   send(s, new_lsp_notification("textDocument/publishDiagnostics", parameters))


proc get_configuration(uri: string): Configuration =
   # Search for a configuration file starting at the file uri and walking up to
   # the root directory. If we find a file but fail to parse it, we fall back to
   # default values.
   log.debug("Searching for a configuration file.")
   let filename = find_configuration_file(get_path_from_uri(uri))
   try:
      result = configuration.parse_file(filename)
      log.debug("Parsed configuration file '$1'.", filename)
      log.debug($result)
   except ConfigurationParseError as e:
      log.error("Failed to parse configuration file: $1", e.msg)
      init(result)


proc process_text(s: var LspServer, uri, text: string) =
   ## Create a new compile unit from the input ``text``. The environment
   ## (include paths etc.) is initialized from the ``uri``. The resulting
   ## compile unit will be indexed with the ``uri`` as key.
   log.debug("Processing text from '$1'.", uri)

   let ss = new_string_stream(text)
   let configuration = get_configuration(uri)
   let cache = new_ident_cache()
   var graph: Graph
   open_graph(graph, cache, ss, get_path_from_uri(uri),
              configuration.include_paths, configuration.defines)
   close(ss)

   # Index the compile unit to be able to analyze the graph when the client
   # makes subsequent request. If an element already exists in the table, we
   # call the close proc before discarding the old compile unit in favor of
   # the new.
   if has_key(s.compile_units, uri):
      log.debug("Closing compile unit for file '$1'.", uri)
      close(s.compile_units[uri])
   log.debug("Adding a new compile unit for the file '$1' to the index.", uri)
   s.compile_units[uri] = CompileUnit(uri: uri, cache: cache, graph: graph,
                                      configuration: configuration)

   if s.client_capabilities.diagnostics or s.force_diagnostics:
      publish_diagnostics(s, s.compile_units[uri])


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
         # FIXME: Read this from a shared static location.
         "version": VERSION
      }
      result["capabilities"] = %*{
         "textDocumentSync": 1,
         "declarationProvider": true
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


proc declaration(s: LspServer, msg: LspMessage) =
   let line = get_int(msg.parameters["position"]["line"])
   let col = get_int(msg.parameters["position"]["character"])
   let uri = get_str(msg.parameters["textDocument"]["uri"])
   if has_key(s.compile_units, uri):
      let locations = find_declaration(s.compile_units[uri].graph, line + 1, col)
      if len(locations) > 0:
         send(s, new_lsp_response(msg.id, %locations))
      else:
         send(s, new_lsp_response(msg.id, new_jnull()))
   else:
      send(s, new_lsp_response(msg.id, RPC_INTERNAL_ERROR, format("File '$1' is not in the index.", uri), nil))


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
   else:
      let str = format("Unsupported method '$1'.", msg.m)
      send(s, new_lsp_response(msg.id, RPC_INVALID_REQUEST, str, nil))


proc initialied(s: LspServer) =
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
      initialied(s)
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
