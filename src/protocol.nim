# This file implements the protocol handling.

import json
import streams
import strutils

export json

type
   Request* = object
      length*: int
      id*: int
      m*: string
      parameters*: JsonNode

   LspError* = object
      code*: int
      message*: string
      data*: JsonNode

   LspResponseKind* = enum
      RkSuccess, RkError

   LspResponse* = object
      id*: int
      case kind: LspResponseKind
      of RkSuccess:
         result*: JsonNode
      of RkError:
         error*: LspError

   RequestParseError* = object of ValueError
   RequestIoError* = object of IOError


const
   RPC_PARSE_ERROR* = -32700
   RPC_INVALID_REQUEST* = -32600
   RPC_METHOD_NOT_FOUND* = -32601
   RPC_INVALID_PARAMS* = -32602
   RPC_INTERNAL_ERROR* = -32603
   RPC_SERVER_ERROR_START* = -32099
   RPC_SERVER_ERROR_END* = -32000
   RPC_SERVER_NOT_INITIALIZED* = -32002
   RPC_UNKNOWN_ERROR_CODE* = -32001
   RPC_REQUEST_CANCELLED* = -32800
   RPC_CONTENT_MODIFIED* = -32801


proc new_request_io_error(msg: string, args: varargs[string, `$`]): ref RequestIoError =
   new result
   result.msg = format(msg, args)


proc new_request_parse_error(msg: string, args: varargs[string, `$`]): ref RequestParseError =
   new result
   result.msg = format(msg, args)


proc new_response(kind: LspResponseKind, id: int): LspResponse =
   result = LspResponse(kind: kind, id: id)


proc new_lsp_success_response*(id: int, res: JsonNode): LspResponse =
   result = new_response(RkSuccess, id)
   result.result = res


proc new_lsp_error_response*(id, code: int, message: string, data: JsonNode): LspResponse =
   result = new_response(RkError, id)
   result.error.code = code
   result.error.message = message
   result.error.data = data


proc parse_headers(s: Stream, r: var Request) =
   var seen_content_length = false

   const CONTENT_LENGTH = "Content-Length: "
   const CONTENT_TYPE = "Content-Type: "
   const CONTENT_TYPE_UTF8 = "application/vscode-jsonrpc; charset=utf-8"

   while true:
      var header = ""
      if not read_line(s, header):
         raise new_request_io_error("Input stream closed unexpectedly.")

      if len(header) == 0:
         # We're done with parsing headers. The message is expected next.
         # However, the Content-Length header is mandatory and if we haven't
         # seen that we have to raise an error.
         if not seen_content_length:
            raise new_request_parse_error("The request is missing the " &
                                          "required header field " &
                                          "'Content-Length'.")
         else:
            break

      if starts_with(header, CONTENT_LENGTH):
         let length = substr(header, len(CONTENT_LENGTH))
         try:
            r.length = parse_int(length)
         except ValueError:
            raise new_request_parse_error("Invalid content length: '$1'.", length)

         seen_content_length = true

      elif starts_with(header, CONTENT_TYPE):
         let content_type = substr(header, len(CONTENT_TYPE))
         if content_type != CONTENT_TYPE_UTF8:
            raise new_request_parse_error(
               "Invalid content type '$1'. Expected '$2'.",
               content_type, CONTENT_TYPE_UTF8
            )

      else:
         raise new_request_parse_error("Invalid request header '$1'.", header)


proc parse_content(s: Stream, r: var Request) =
   let content = read_str(s, r.length)
   let node =
      try:
         parse_json(content)
      except JsonParsingError:
         raise new_request_parse_error("Parsing error when processing JSON content.")

   # Validate JSON object.
   if node.kind != JObject:
      raise new_request_parse_error("Content is not a JSON object.")

   # Validate JSON RPC version.
   try:
      if get_str(node["jsonrpc"]) != "2.0":
         raise new_request_parse_error(
            "Expected JSON RPC version 2.0, got '$1'.", node["jsonrpc"]
         )
   except KeyError:
      raise new_request_parse_error("Expected key 'jsonrpc'.")

   # Handle the request id.
   try:
      case node["id"].kind
      of JInt:
         r.id = get_int(node["id"])
      of JString:
         r.id = parse_int(get_str(node["id"]))
      else:
         raise new_request_parse_error(
            "Unexpected type of 'id' field, expected an integer or a string.")
   except KeyError:
      raise new_request_parse_error("Expected key 'id'.")
   except ValueError:
      raise new_request_parse_error("Invalid id '$1'.", get_str(node["id"]))

   # Handle the request method.
   try:
      if node["method"].kind != JString:
         raise new_request_parse_error("Unexpected type of 'method' field, " &
                                       "expected a string.")
      r.m = get_str(node["method"])
   except KeyError:
      raise new_request_parse_error("Expected key 'method'.")

   # Handle the parameters.
   if has_key(node, "params"):
      case node["params"].kind
      of JObject, JArray:
         r.parameters = node["params"]
      else:
         raise new_request_parse_error(
            "Request field 'params' has to be either an object or an array.")


proc recv_request*(s: Stream): Request =
   # Read the header part. Any parse error will raise an exception which should
   # propagate to the caller and generate an error response.
   parse_headers(s, result)

   # Read the content part.
   parse_content(s, result)


proc `%`(e: LspError): JsonNode =
   result = %*{
      "code": e.code,
      "message": e.message
   }
   if e.data != nil:
      result["data"] = e.data


proc `%`(r: LspResponse): JsonNode =
   # If there's an error object,
   case r.kind
   of RkSuccess:
      result = %*{
         "jsonrpc": "2.0",
         "id": %r.id,
         "result": r.result
      }
   of RkError:
      result = %*{
         "jsonrpc": "2.0",
         "id": %r.id,
         "error": %r.error
      }


proc send_response*(s: Stream, r: LspResponse) =
   write(s, $(%r))
