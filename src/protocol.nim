# This file implements the protocol handling.

import json
import streams
import strutils

export json

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


proc `$`(kind: LspMessageKind): string =
   result = LspMessageKindToStr[kind]


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


proc new_lsp_request_message*(length, id: int, m: string, parameters: JsonNode): LspMessage =
   init(result)
   result.kind = MkRequest
   result.length = length
   result.id = id
   result.m = m
   result.parameters = parameters


proc new_lsp_response*(id: int, res: JsonNode): LspMessage =
   init(result)
   result.kind = MkResponseSuccess
   result.id = id
   result.result = res


proc new_lsp_response*(id: int, code: LspErrorCode, message: string, data: JsonNode): LspMessage =
   init(result)
   result.kind = MkResponseError
   result.id = id
   result.error.message = message
   result.error.code = code
   result.error.data = data


proc new_lsp_io_error(msg: string, args: varargs[string, `$`]): ref LspIoError =
   new result
   result.msg = format(msg, args)


proc new_lsp_parse_error(msg: string, args: varargs[string, `$`]): ref LspParseError =
   new result
   result.msg = format(msg, args)


proc new_lsp_value_error(msg: string, args: varargs[string, `$`]): ref LspValueError =
   new result
   result.msg = format(msg, args)


proc parse_headers(s: Stream, r: var LspMessage) =
   var seen_content_length = false

   const CONTENT_LENGTH = "Content-Length: "
   const CONTENT_TYPE = "Content-Type: "

   while true:
      var header = ""
      if not read_line(s, header):
         raise new_lsp_io_error("Input stream closed unexpectedly.")

      if len(header) == 0:
         # We're done with parsing headers. The message is expected next.
         # However, the Content-Length header is mandatory and if we haven't
         # seen that we have to raise an error.
         if not seen_content_length:
            raise new_lsp_parse_error("The request is missing the " &
                                          "required header field " &
                                          "'Content-Length'.")
         else:
            break

      if starts_with(header, CONTENT_LENGTH):
         let length = substr(header, len(CONTENT_LENGTH))
         try:
            r.length = parse_int(length)
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


proc parse_content(s: Stream, r: var LspMessage) =
   let content = read_str(s, r.length)
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

   # Handle the request id.
   try:
      case node["id"].kind
      of JInt:
         r.id = get_int(node["id"])
      of JString:
         r.id = parse_int(get_str(node["id"]))
      else:
         raise new_lsp_parse_error(
            "Unexpected type of 'id' field, expected an integer or a string.")
   except KeyError:
      raise new_lsp_parse_error("Expected key 'id'.")
   except ValueError:
      raise new_lsp_parse_error("Invalid id '$1'.", get_str(node["id"]))

   # Handle the request method.
   try:
      if node["method"].kind != JString:
         raise new_lsp_parse_error("Unexpected type of 'method' field, " &
                                       "expected a string.")
      r.m = get_str(node["method"])
   except KeyError:
      raise new_lsp_parse_error("Expected key 'method'.")

   # Handle the parameters.
   if has_key(node, "params"):
      case node["params"].kind
      of JObject, JArray:
         r.parameters = node["params"]
      else:
         raise new_lsp_parse_error(
            "LspRequest field 'params' has to be either an object or an array.")


proc recv_request*(s: Stream): LspMessage =
   init(result)
   result.kind = MkRequest
   # Read the header part. Any parse error will raise an exception which should
   # propagate to the caller and generate an error response.
   parse_headers(s, result)

   # Read the content part.
   parse_content(s, result)


proc `%`(e: LspError): JsonNode =
   result = %*{
      "code": int(e.code),
      "message": e.message
   }
   if e.data != nil:
      result["data"] = e.data


proc `%`(r: LspMessage): JsonNode =
   case r.kind
   of MkResponseSuccess:
      result = %*{
         "jsonrpc": "2.0",
         "id": %r.id,
         "result": r.result
      }
   of MkResponseError:
      result = %*{
         "jsonrpc": "2.0",
         "id": %r.id,
         "error": %r.error
      }
   else:
      raise new_lsp_value_error("Unexpected LSP message kind '$1'.", r.kind)


proc send_response*(s: Stream, r: LspMessage) =
   let content = $(%r)
   var message = format("Content-Length: $1\r\nContent-Type: $2\r\n\r\n",
                        len(content), CONTENT_TYPE_UTF8) & content
   write(s, message)
