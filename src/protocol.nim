# This file implements the protocol handling.

import json
import streams
import strutils
import ./log

type
   LspErrorCode* = enum
      RPC_CONTENT_MODIFIED = -32801
      RPC_REQUEST_CANCELLED = -32800
      RPC_PARSE_ERROR = -32700
      RPC_INTERNAL_ERROR = -32603
      RPC_INVALID_PARAMS = -32602
      RPC_METHOD_NOT_FOUND = -32601
      RPC_INVALID_REQUEST = -32600
      RPC_SERVER_ERROR_START = -32099
      RPC_SERVER_NOT_INITIALIZED = -32002
      RPC_UNKNOWN_ERROR_CODE = -32001
      RPC_SERVER_ERROR_END = -32000
      RPC_INVALID = 0

   LspMessageKind* = enum
      MkInvalid, MkRequest, MkNotification, MkResponseSuccess, MkResponseError

   LspError* = object
      code*: LspErrorCode
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


const
   CONTENT_TYPE_UTF8 = "application/vscode-jsonrpc; charset=utf-8"

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


proc `$`(kind: LspMessageKind): string =
   result = LspMessageKindToStr[kind]


proc `%`(e: LspError): JsonNode =
   result = %*{
      "code": int(e.code),
      "message": e.message
   }
   if e.data != nil:
      result["data"] = e.data


proc `%`(msg: LspMessage): JsonNode =
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


proc new_lsp_response*(id: int, code: LspErrorCode, message: string, data: JsonNode): LspMessage =
   init(result)
   result.kind = MkResponseError
   result.id = id
   result.error.message = message
   result.error.code = code
   result.error.data = data


proc new_lsp_response*(length, id: int, code: LspErrorCode, message: string, data: JsonNode): LspMessage =
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
      msg.error.code = LspErrorCode(get_int(content["error"]["code"]))
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
