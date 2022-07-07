# This file implements the protocol handling.

import json
import streams
import strutils
import ./log

type
   LspMessageKind* = enum
      MkInvalid, MkRequest, MkNotification, MkResponseSuccess, MkResponseError

   LspError* = object
      code*: int
      message*: string
      data*: JsonNode

   LspMessage* = object
      kind*: LspMessageKind
      length*: int
      id*: int
      m*: string
      parameters*: JsonNode
      result*: JsonNode
      error*: LspError

   LspRequest* = object
      length*: int
      id*: int
      m*: string
      parameters*: JsonNode

   LspResponseKind* = enum
      RkSuccess, RkError

   LspResponse* = object
      id*: int
      case kind: LspResponseKind
      of RkSuccess:
         result*: JsonNode
      of RkError:
         error*: LspError

   LspParseError* = object of ValueError
   LspValueError* = object of ValueError
   LspIoError* = object of IOError

   LspPosition* = object
      # Lines and columns are zero-based.
      line*, col*: int

   LspRange* = object
      start*, stop*: LspPosition

   LspLocation* = object
      uri*: string
      range*: LspRange

   LspSeverity* = enum
      ERROR = 1
      WARNING = 2
      INFO = 3
      HINT = 4

   LspDiagnostic* = object
      range*: LspRange
      severity*: LspSeverity
      message*: string

   LspCompletionKind* = enum
      LspCkText = 1
      LspCkMethod = 2
      LspCkFunction = 3
      LspCkConstructor = 4
      LspCkField = 5
      LspCkVariable = 6
      LspCkClass = 7
      LspCkInterface = 8
      LspCkModule = 9
      LspCkProperty = 10
      LspCkUnit = 11
      LspCkValue = 12
      LspCkEnum = 13
      LspCkKeyword = 14
      LspCkSnippet = 15
      LspCkColor = 16
      LspCkFile = 17
      LspCkReference = 18
      LspCkFolder = 19
      LspCkEnumMember = 20
      LspCkConstant = 21
      LspCkStruct = 22
      LspCkEvent = 23
      LspCkOperator = 24
      LspCkTypeParameter = 25

   LspCompletionItem* = object
      label*: string
      detail*: string
      documentation*: LspMarkupContent
      kind*: LspCompletionKind
      insert_text*: string

   LspSymbolKind* = enum
      LspSkFile = 1
      LspSkModule = 2
      LspSkNamespace = 3
      LspSkPackage = 4
      LspSkClass = 5
      LspSkMethod = 6
      LspSkProperty = 7
      LspSkField = 8
      LspSkConstructor = 9
      LspSkEnum = 10
      LspSkInterface = 11
      LspSkFunction = 12
      LspSkVariable = 13
      LspSkConstant = 14
      LspSkString = 15
      LspSkNumber = 16
      LspSkBoolean = 17
      LspSkArray = 18
      LspSkObject = 19
      LspSkKey = 20
      LspSkNull = 21
      LspSkEnumMember = 22
      LspSkStruct = 23
      LspSkEvent = 24
      LspSkOperator = 25
      LspSkTypeParameter = 26

   LspSymbolInformation* = object
      name*: string
      kind*: LspSymbolKind
      location*: LspLocation
      container_name*: string

   LspTextEdit* = object
      range*: LspRange
      text*: string

   LspTextDocumentEdit* = object
      version*: int
      uri*: string
      edits*: seq[LspTextEdit]

   LspDocumentHighlightKind* = enum
      LspHkText = 1
      LspHkRead = 2
      LspHkWrite = 3

   LspDocumentHighlight* = object
      range*: LspRange
      kind*: LspDocumentHighlightKind

   LspMarkupKind* = enum
      LspMkPlainText
      LspMkMarkdown

   LspMarkupContent* = object
      kind*: LspMarkupKind
      value*: string

   LspHover* = object
      contents*: LspMarkupContent
      range*: LspRange

   LspParameterInformation* = object
      label*: string
      documentation: LspMarkupContent

   LspSignatureInformation* = object
      label*: string
      documentation*: LspMarkupContent
      parameters*: seq[LspParameterInformation]

   LspSignatureHelp* = object
      signatures*: seq[LspSignatureInformation]
      active_signature*: int
      active_parameter*: int


const
   INDENT = 2
   CONTENT_TYPE_UTF8 = "application/vscode-jsonrpc; charset=utf-8"

   # LSP error codes. These cannot be an enum since there are holes
   # in the sequence.
   RPC_CONTENT_MODIFIED* = -32801
   RPC_REQUEST_CANCELLED* = -32800
   RPC_PARSE_ERROR* = -32700
   RPC_INTERNAL_ERROR* = -32603
   RPC_INVALID_PARAMS* = -32602
   RPC_METHOD_NOT_FOUND* = -32601
   RPC_INVALID_REQUEST* = -32600
   RPC_SERVER_ERROR_START* = -32099
   RPC_SERVER_NOT_INITIALIZED* = -32002
   RPC_UNKNOWN_ERROR_CODE* = -32001
   RPC_SERVER_ERROR_END* = -32000
   RPC_INVALID = 0

   LspMessageKindToStr: array[LspMessageKind, string] = [
      "Invalid", "Request", "Notification", "Response: success", "Response: error"
   ]


proc new_lsp_io_error(msg: string, args: varargs[string, `$`]): ref LspIoError =
   new result
   result.msg = format(msg, args)


proc new_lsp_parse_error(msg: string, args: varargs[string, `$`]): ref LspParseError =
   new result
   result.msg = format(msg, args)


proc new_lsp_value_error(msg: string, args: varargs[string, `$`]): ref LspValueError =
   new result
   result.msg = format(msg, args)


proc new_lsp_position*(line, col: int): LspPosition =
   result.line = line
   result.col = col


proc new_lsp_location*(uri: string, line, col, len: int): LspLocation =
   # The stop position is exclusive so to highlight the full length we
   # need to point one position past the final character.
   let start = new_lsp_position(line, col)
   let stop = new_lsp_position(line, col + len)
   result.uri = uri
   result.range = LspRange(start: start, stop: stop)


proc new_lsp_diagnostic*(start, stop: LspPosition, severity: LspSeverity,
                         message: string): LspDiagnostic =
   result.range = LspRange(start: start, stop: stop)
   result.severity = severity
   result.message = message


proc new_lsp_completion_item*(label: string): LspCompletionItem =
   result.label = label
   result.kind = LspCkText
   set_len(result.insert_text, 0)
   set_len(result.detail, 0)
   set_len(result.documentation.value, 0)


proc new_lsp_symbol_information*(name: string, kind: LspSymbolKind, loc: LspLocation): LspSymbolInformation =
   result.name = name
   result.kind = kind
   result.location = loc


proc new_lsp_text_edit*(start, stop: LspPosition, text: string): LspTextEdit =
   result.range = LspRange(start: start, stop: stop)
   result.text = text


proc new_lsp_text_document_edit*(uri: string, edits: openarray[LspTextEdit]): LspTextDocumentEdit =
   result.uri = uri
   result.version = -1
   set_len(result.edits, 0)
   add(result.edits, edits)


proc new_lsp_document_highlight*(start, stop: LspPosition, kind: LspDocumentHighlightKind): LspDocumentHighlight =
   result.range = LspRange(start: start, stop: stop)
   result.kind = kind


proc new_lsp_hover*(line, col, len: int, kind: LspMarkupKind, contents: string): LspHover =
   let start = new_lsp_position(line, col)
   let stop = new_lsp_position(line, col + len)
   result.range = LspRange(start: start, stop: stop)
   result.contents = LspMarkupContent(kind: kind, value: contents)


proc new_lsp_parameter_information*(label: string, kind: LspMarkupKind, value: string): LspParameterInformation =
   result.label = label
   result.documentation = LspMarkupContent(kind: kind, value: value)


proc new_lsp_signature_information*(label: string, kind: LspMarkupKind, value: string): LspSignatureInformation =
   result.label = label
   result.documentation = LspMarkupContent(kind: kind, value: value)
   set_len(result.parameters, 0)


proc new_lsp_signature_help*(signatures: seq[LspSignatureInformation],
                             active_signature, active_parameter: int): LspSignatureHelp =
   result.signatures = signatures
   result.active_signature = active_signature
   result.active_parameter = active_parameter


proc `%`*(p: LspPosition): JsonNode =
   result = %*{
      "line": p.line,
      "character": p.col
   }


proc `%`*(r: LspRange): JsonNode =
   result = %*{
      "start": r.start,
      "end": r.stop
   }


proc `%`*(d: LspDiagnostic): JsonNode =
   result = %*{
      "range": d.range,
      "severity": int(d.severity),
      "message": d.message
   }


proc `%`*(l: LspLocation): JsonNode =
   result = %*{
      "uri": l.uri,
      "range": l.range
   }


proc `%`*(o: LspSymbolInformation): JsonNode =
   result = %*{
      "name": o.name,
      "kind": int(o.kind),
      "location": %o.location
   }
   if len(o.container_name) > 0:
      result["containerName"] = %o.container_name


proc `%`*(o: LspTextEdit): JsonNode =
   result = %*{
      "range": o.range,
      "newText": o.text
   }


proc `%`*(o: LspTextDocumentEdit): JsonNode =
   result = %*{
      "textDocument": {
         "version": new_jnull(),
         "uri": o.uri
      },
      "edits": o.edits
   }


proc `%`*(o: LspDocumentHighlight): JsonNode =
   result = %*{
      "range": o.range,
      "kind": int(o.kind)
   }


proc `%`*(o: LspMarkupContent): JsonNode =
   result = %*{
      "kind": if o.kind == LspMkPlainText: "plaintext" else: "markdown",
      "value": o.value
   }


proc `%`*(o: LspHover): JsonNode =
   result = %*{
      "range": o.range,
      "contents": o.contents
   }


proc `%`*(o: LspParameterInformation): JsonNode =
   result = %*{
      "label": o.label,
      "documentation": o.documentation
   }


proc `%`*(o: LspSignatureInformation): JsonNode =
   result = %*{
      "label": o.label,
      "documentation": o.documentation,
      "parameters": o.parameters
   }


proc `%`*(o: LspSignatureHelp): JsonNode =
   result = %*{
      "signatures": o.signatures,
      "activeSignature": o.active_signature,
      "activeParameter": o.active_parameter
   }


proc `%`*(o: LspCompletionItem): JsonNode =
   result = %*{
      "label": o.label,
      "kind": int(o.kind)
   }
   if len(o.detail) > 0:
      result["detail"] = %o.detail
   if len(o.documentation.value) > 0:
      result["documentation"] = %o.documentation
   if len(o.insert_text) > 0:
      result["insertText"] = %o.insert_text


proc `$`*(kind: LspMessageKind): string =
   result = LspMessageKindToStr[kind]


proc `%`*(e: LspError): JsonNode =
   result = %*{
      "code": int(e.code),
      "message": e.message
   }
   if e.data != nil:
      result["data"] = e.data


proc `%`*(msg: LspMessage): JsonNode =
   case msg.kind
   of MkRequest:
      result = %*{
         "jsonrpc": "2.0",
         "id": msg.id,
         "method": msg.m,
      }
      if msg.parameters != nil:
         result["params"] = msg.parameters
   of MkResponseSuccess:
      result = %*{
         "jsonrpc": "2.0",
         "id": msg.id,
         "result": msg.result
      }
   of MkResponseError:
      result = %*{
         "jsonrpc": "2.0",
         "id": msg.id,
         "error": %msg.error
      }
   of MkNotification:
      result = %*{
         "jsonrpc": "2.0",
         "method": msg.m,
      }
      if msg.parameters != nil:
         result["params"] = msg.parameters
   else:
      raise new_lsp_value_error("Unexpected LSP message kind '$1'.", msg.kind)


proc unordered_compare*(x, y: JsonNode): bool =
   # Helper proc to compare two JSON nodes from an LSP message. Arrays are compared
   # without regard to the order of the elements.
   if x.kind != y.kind:
      return false

   case x.kind
   of JObject:
      for k, v in pairs(x):
         if not has_key(y, k) or y[k].kind != v.kind or not unordered_compare(v, y[k]):
            return false
      return true
   of JArray:
      if len(x) != len(y):
         return false

      var skip_idx: seq[int]
      for i in 0..<len(x):
         var found = false
         for j in 0..<len(y):
            if j in skip_idx:
               continue
            elif unordered_compare(x[i], y[j]):
               found = true
               add(skip_idx, j)
               break
         if not found:
            return false
      return true
   else:
      # Compare the values.
      return x == y


proc unordered_compare*(x, y: LspMessage): bool =
   # Used by the test framework.
   if x.kind != y.kind:
      return false
   if x.length != y.length:
      return false

   if x.kind == MkResponseSuccess:
      if x.id != y.id:
         return false
      if x.result != nil and y.result != nil:
         return unordered_compare(x.result, y.result)
      else:
         return false
   else:
      return false


proc detailed_compare(x, y: JsonNode, label: string, indent: int = 0) =
   # Helper proc to compare two JSON nodes from an LSP message.
   if x.kind != y.kind:
      echo format("JSON node $1:", label)
      echo indent(format("Kind differs for JSON node '$1': $2 != $3.", label, x.kind, y.kind), indent)

   case x.kind
   of JObject:
      # Go through the objects, recursively calling detailed_compare for each value.
      for k, v in pairs(x):
         if not has_key(y, k):
            echo indent(format("Expected key '$1' in object '$2'.", k, label), indent)
         elif y[k].kind != v.kind:
            echo indent(format("Kind differs for JSON node $1: $2 != $3.", label, x.kind, y.kind), indent)
         else:
            detailed_compare(v, y[k], label & "." & k, indent + INDENT)
   of JArray:
      # Go through the array, recursively calling detailed_compare for each value.
      if len(x) != len(y):
         echo indent(format("Array length mismatch for JSON node '$1': $2 != $3.", label, len(x), len(y)), indent)
      for i in 0..<len(x):
         detailed_compare(x[i], y[i], label & "[" & $i & "]", indent + INDENT)
   else:
      # Compare the values.
      if x != y:
         echo indent(format("Value differs for node $1:", label, x, y), indent)
         echo indent(format("Got: $1", x), indent + INDENT)
         echo indent(format("Exp: $1", y), indent + INDENT)


proc detailed_compare(x, y: LspError) =
   if x.code != y.code:
      echo format("Error code differs: $1 != $2.", x.code, y.code)

   if x.message != y.message:
      echo format("Message differs: $1 != $2.", x.message, y.message)

   if x.data != nil:
      if y.data != nil:
         detailed_compare(x.data, y.data, "error.data", INDENT)
      else:
         echo "Expected a 'data' field for LSP error."


proc detailed_compare*(x, y: LspMessage) =
   # Used by the test framework.
   if x.kind != y.kind:
      echo format("Kind differs: $1 != $2", x.kind, y.kind)
      return

   if x.length != y.length:
      echo format("Length differs: $1 != $2", x.length, y.length)
      return

   case x.kind
   of MkRequest:
      if x.id != y.id:
         echo format("Id differs: $1 != $2", x.id, y.id)
      if x.m != y.m:
         echo format("Method differs: $1 != $2", x.m, y.m)
      if x.parameters != nil and y.parameters != nil:
         detailed_compare(x.parameters, y.parameters, "parameters")

   of MkResponseSuccess:
      if x.id != y.id:
         echo format("Id differs: $1 != $2", x.id, y.id)

      if x.result != nil and y.result != nil:
         detailed_compare(x.result, y.result, "result")
      else:
         echo "Expected a 'result' field."

   of MkResponseError:
      if x.id != y.id:
         echo format("Id differs: $1 != $2", x.id, y.id)
      detailed_compare(x.error, y.error)

   of MkNotification:
      if x.m != y.m:
         echo format("Method differs: $1 != $2", x.m, y.m)
      if x.parameters != nil and y.parameters != nil:
         detailed_compare(x.parameters, y.parameters, "parameters")

   of MkInvalid:
      discard


template get_path_from_uri*(uri: string): string =
   # On Windows, the uri will look like "file:///c:/path/to/some/file" and the
   # path part is "/c:/path/to/some/file". The leading '/' needs to be removed
   # in order for the path to be valid.
   when defined(windows):
      replace(strip(parse_uri(uri).path, true, false, {'/'}), '/', '\\')
   else:
      parse_uri(uri).path


template construct_uri*(filename: string): string =
   when defined(windows):
      "file:///" & replace(filename, '\\', '/')
   else:
      "file://" & filename


proc len(msg: LspMessage): int =
   result = len($(%msg))


proc init(e: var LspError) =
   e.code = RPC_INVALID
   set_len(e.message, 0)
   e.data = nil


proc init*(msg: var LspMessage) =
   msg.kind = MkInvalid
   msg.length = 0
   msg.id = 0
   set_len(msg.m, 0)
   msg.parameters = nil
   msg.result = nil
   init(msg.error)


proc new_lsp_request*(id: int, m: string, parameters: JsonNode): LspMessage =
   init(result)
   result.kind = MkRequest
   result.id = id
   result.m = m
   result.parameters = parameters
   result.length = len(result)


proc new_lsp_request*(length, id: int, m: string, parameters: JsonNode): LspMessage =
   # Used by the test framework.
   result = new_lsp_request(id, m, parameters)
   result.length = length


proc new_lsp_notification*(m: string, parameters: JsonNode): LspMessage =
   init(result)
   result.kind = MkNotification
   result.m = m
   result.parameters = parameters


proc new_lsp_notification*(length: int, m: string, parameters: JsonNode): LspMessage =
   # Used by the test framework.
   result = new_lsp_notification(m, parameters)
   result.length = length


proc new_lsp_response*(id: int, res: JsonNode): LspMessage =
   init(result)
   result.kind = MkResponseSuccess
   result.id = id
   result.result = res


proc new_lsp_response*(length, id: int, res: JsonNode): LspMessage =
   # Used by the test framework.
   result = new_lsp_response(id, res)
   result.length = length


proc new_lsp_response*(id: int, code: int, message: string, data: JsonNode): LspMessage =
   init(result)
   result.kind = MkResponseError
   result.id = id
   result.error.message = message
   result.error.code = code
   result.error.data = data


proc new_lsp_response*(length, id: int, code: int, message: string, data: JsonNode): LspMessage =
   # Used by the test framework.
   result = new_lsp_response(id, code, message, data)
   result.length = length


proc parse_headers(s: Stream, msg: var LspMessage) =
   var seen_content_length = false

   const CONTENT_LENGTH = "Content-Length: "
   const CONTENT_TYPE = "Content-Type: "

   while true:
      var header = ""
      if not read_line(s, header):
         raise new_lsp_io_error("Input stream closed unexpectedly.")

      if len(header) == 0:
         # We're done with parsing headers. The message is expected next.
         # However, the Content-Length header is mandatory so if we haven't
         # seen that we have to raise an error.
         if not seen_content_length:
            raise new_lsp_parse_error("The request is missing the required header field 'Content-Length'.")
         else:
            break

      if starts_with(header, CONTENT_LENGTH):
         let length = substr(header, len(CONTENT_LENGTH))
         try:
            msg.length = parse_int(length)
         except ValueError:
            raise new_lsp_parse_error("Invalid content length: '$1'.", length)

         seen_content_length = true

      elif starts_with(header, CONTENT_TYPE):
         let content_type = substr(header, len(CONTENT_TYPE))
         if content_type != CONTENT_TYPE_UTF8:
            raise new_lsp_parse_error(
               "Invalid content type '$1'. Expected '$2'.",
               content_type, CONTENT_TYPE_UTF8
            )

      else:
         raise new_lsp_parse_error("Invalid request header '$1'.", header)


proc parse_method(content: JsonNode, msg: var LspMessage) =
   # It's an error if the 'method' field is not present.
   try:
      if content["method"].kind != JString:
         raise new_lsp_parse_error("Unexpected type of 'method' field, expected a string.")
      msg.m = get_str(content["method"])
   except KeyError:
      raise new_lsp_parse_error("Expected key 'method'.")


proc parse_parameters(content: JsonNode, msg: var LspMessage) =
   # The 'params' field is optional but has to be an array if present.
   if has_key(content, "params"):
      case content["params"].kind
      of JObject, JArray:
         msg.parameters = content["params"]
      else:
         raise new_lsp_parse_error("LSP message field 'params' has to be either an object or an array.")


proc parse_error(content: JsonNode, msg: var LspMessage) =
   if content["error"].kind != JObject:
      raise new_lsp_parse_error("LSP message field 'error' has to be an object.")

   try:
      if content["error"]["code"].kind != JInt:
         raise new_lsp_parse_error("LSP message field 'error.code' has to be an integer.")
      msg.error.code = get_int(content["error"]["code"])
   except KeyError:
      raise new_lsp_parse_error("Expected key 'code'.")

   try:
      if content["error"]["message"].kind != JString:
         raise new_lsp_parse_error("LSP message field 'error.message' has to be a string.")
      msg.error.message = get_str(content["error"]["message"])
   except KeyError:
      raise new_lsp_parse_error("Expected key 'message'.")

   if has_key(content["error"], "data"):
      msg.error.data = content["error"]["data"]


proc parse_request_or_response(content: JsonNode, msg: var LspMessage) =
   case content["id"].kind
   of JInt:
      msg.id = get_int(content["id"])
   of JString:
      try:
         msg.id = parse_int(get_str(content["id"]))
      except ValueError:
         raise new_lsp_parse_error("Invalid id '$1'.", get_str(content["id"]))
   else:
      raise new_lsp_parse_error("Unexpected type of 'id' field, expected an integer or a string.")

   # The 'method' field is required for requests. If it's not present, we assume
   # that we're parsing an LSP response.
   if has_key(content, "method"):
      parse_method(content, msg)
      parse_parameters(content, msg)
      msg.kind = MkRequest
   else:
      let has_result = has_key(content, "result")
      let has_error = has_key(content, "error")
      if has_result and has_error:
         raise new_lsp_parse_error("Exactly one of the fields 'result' or 'error' is expected for an LSP response but both are present.")
      elif has_result:
         msg.result = content["result"]
         msg.kind = MkResponseSuccess
      elif has_error:
         parse_error(content, msg)
         msg.kind = MkResponseError
      else:
         raise new_lsp_parse_error("Exactly one of the fields 'result' or 'error' is expected for an LSP response but both are missing.")


proc parse_notification(content: JsonNode, msg: var LspMessage) =
   parse_method(content, msg)
   parse_parameters(content, msg)
   msg.kind = MkNotification


proc parse_content(s: Stream, msg: var LspMessage) =
   let content = read_str(s, msg.length)
   let node =
      try:
         parse_json(content)
      except JsonParsingError:
         raise new_lsp_parse_error("Parsing error when processing JSON content.")

   # Validate JSON object.
   if node.kind != JObject:
      raise new_lsp_parse_error("Content is not a JSON object.")

   # Validate JSON RPC version.
   try:
      if get_str(node["jsonrpc"]) != "2.0":
         raise new_lsp_parse_error(
            "Expected JSON RPC version 2.0, got '$1'.", node["jsonrpc"]
         )
   except KeyError:
      raise new_lsp_parse_error("Expected key 'jsonrpc'.")

   # Handle the request id. If the 'id' field is present, this is a a request or
   # a response message. Otherwise, it's a notification message.
   if has_key(node, "id"):
      parse_request_or_response(node, msg)
   else:
      parse_notification(node, msg)


proc recv*(s: Stream): LspMessage =
   if s == nil:
      # FIXME: Exception?
      return

   init(result)
   # Read the header part. Any parse error will raise an exception which should
   # propagate to the caller and generate an error response.
   parse_headers(s, result)

   # Read the content part.
   parse_content(s, result)


proc send*(s: Stream, msg: LspMessage) =
   if s == nil:
      return

   let content = $(%msg)
   var message = format("Content-Length: $1\r\nContent-Type: $2\r\n\r\n",
                        len(content), CONTENT_TYPE_UTF8) & content
   log.debug("Sending message:\r\n" & message)
   write(s, message)
   flush(s)


proc descend_object*(n: JsonNode, keys: openarray[string]): tuple[n: JsonNode, key: string] =
   ## Descend into a nested JSON object using ``keys``. In the case of an error, an
   ## ``LspParseError`` exception is raised.
   result = (n, "root")
   for key in keys:
      if (result.n.kind != JObject):
         raise new_lsp_parse_error("Expected a JSON object as value to '$1'.", result.key)
      elif not has_key(result.n, key):
         raise new_lsp_parse_error("No '$1' key found in '$2' object.", key, result.key)
      else:
         result = (result.n[key], key)


proc validate_string*(n: JsonNode, keys: openarray[string]): string =
   ## Descend into a nested JSON object using ``keys`, expecting a string value
   ## at the end. In the case of an error, an ``LspParseError`` exception is raised.
   let (ln, key) = descend_object(n, keys)
   if ln.kind != JString:
      raise new_lsp_parse_error("Invalid string for '$1'.", key)
   result = get_str(ln)


proc validate_int*(n: JsonNode, keys: openarray[string]): int =
   ## Descend into a nested JSON object using ``keys`, expecting an integer value
   ## at the end. In the case of an error, an ``LspParseError`` exception is raised.
   let (ln, key) = descend_object(n, keys)
   if ln.kind != JInt:
      raise new_lsp_parse_error("Invalid integer for '$1'.", key)
   result = get_int(ln)


proc validate_bool*(n: JsonNode, keys: openarray[string]): bool =
   ## Descend into a nested JSON object using ``keys`, expecting a boolean value
   ## at the end. In the case of an error, an ``LspParseError`` exception is raised.
   let (ln, key) = descend_object(n, keys)
   if ln.kind != JBool:
      raise new_lsp_parse_error("Invalid boolean for '$1'.", key)
   result = get_bool(ln)
