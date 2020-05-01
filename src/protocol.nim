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

   RequestValueError* = object of ValueError
   RequestIoError* = object of IOError


proc new_request_io_error(msg: string, args: varargs[string, `$`]): ref RequestIoError =
   new result
   result.msg = format(msg, args)


proc new_request_value_error(msg: string, args: varargs[string, `$`]): ref RequestValueError =
   new result
   result.msg = format(msg, args)


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
            raise new_request_value_error("The request is missing the " &
                                          "required header field " &
                                          "'Content-Length'.")
         else:
            break

      if starts_with(header, CONTENT_LENGTH):
         let length = substr(header, len(CONTENT_LENGTH))
         try:
            r.length = parse_int(length)
         except ValueError:
            raise new_request_value_error("Invalid content length: '$1'.", length)

         seen_content_length = true

      elif starts_with(header, CONTENT_TYPE):
         let content_type = substr(header, len(CONTENT_TYPE))
         if content_type != CONTENT_TYPE_UTF8:
            raise new_request_value_error(
               "Invalid content type '$1'. Expected '$2'.",
               content_type, CONTENT_TYPE_UTF8
            )

      else:
         raise new_request_value_error("Invalid request header '$1'.", header)


proc parse_content(s: Stream, r: var Request) =
   let content = read_str(s, r.length)
   let node =
      try:
         parse_json(content)
      except JsonParsingError:
         raise new_request_value_error("Parsing error when processing JSON content.")

   # Validate JSON object.
   if node.kind != JObject:
      raise new_request_value_error("Content is not a JSON object.")

   # Validate JSON RPC version.
   try:
      if get_str(node["jsonrpc"]) != "2.0":
         raise new_request_value_error(
            "Expected JSON RPC version 2.0, got '$1'.", node["jsonrpc"]
         )
   except KeyError:
      raise new_request_value_error("Expected key 'jsonrpc'.")

   # Handle the request id.
   try:
      case node["id"].kind
      of JInt:
         r.id = get_int(node["id"])
      of JString:
         r.id = parse_int(get_str(node["id"]))
      else:
         raise new_request_value_error(
            "Unexpected type of 'id' field, expected an integer or a string.")
   except KeyError:
      raise new_request_value_error("Expected key 'id'.")
   except ValueError:
      raise new_request_value_error("Invalid id '$1'.", get_str(node["id"]))

   # Handle the request method.
   try:
      if node["method"].kind != JString:
         raise new_request_value_error("Unexpected type of 'method' field, " &
                                       "expected a string.")
      r.m = get_str(node["method"])
   except KeyError:
      raise new_request_value_error("Expected key 'method'.")

   # Handle the parameters.
   if has_key(node, "params"):
      case node["params"].kind
      of JObject, JArray:
         r.parameters = node["params"]
      else:
         raise new_request_value_error(
            "Request field 'params' has to be either an object or an array.")


proc recv_request*(s: Stream): Request =
   # Read the header part. Any parse error will raise an exception which should
   # propagate to the caller and generate an error response.
   parse_headers(s, result)

   # Read the content part.
   parse_content(s, result)
