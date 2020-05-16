# This file implement a collection of convencience procs to initialize the LSP
# server, making it ready for the rest of the test framework.

import streams
import json
import ../../src/protocol

proc initialize*(to_server, from_server: Stream) =
   let initialize_request = new_lsp_request(0, "initialize", %*{
      "processId": new_jnull(),
      "clientInfo": "VLS test client",
      "rootUri": new_jnull(),
      "capabilities": {
         "textDocument": {
            "publishDiagnostics": {},
         }
      }
   })
   send(to_server, initialize_request)
   discard recv(from_server)

   let initialized_notification = new_lsp_notification("initialized", nil)
   send(to_server, initialized_notification)


proc shutdown*(to_server, from_server: Stream) =
   discard
   send(to_server, new_lsp_request(0, "shutdown", nil))
   discard recv(from_server)
   send(to_server, new_lsp_notification("exit", nil))
