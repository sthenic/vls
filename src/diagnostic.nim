import json

type
   LspPosition* = object
      # Lines and columns are zero-based.
      line*, col*: int

   LspRange* = object
      start*, stop*: LspPosition

   LspLocation* = object
      uri*: string
      rng*: LspRange

   LspSeverity* = enum
      ERROR = 1
      WARNING = 2
      INFO = 3
      HINT = 4

   LspDiagnostic* = object
      rng*: LspRange
      severity*: LspSeverity
      message*: string


proc new_lsp_position*(line, col: int): LspPosition =
   result.line = line
   result.col = col


proc new_lsp_diagnostic*(start, stop: LspPosition, severity: LspSeverity,
                         message: string): LspDiagnostic =
   result.rng = LspRange(start: start, stop: stop)
   result.severity = severity
   result.message = message


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
      "range": d.rng,
      "severity": int(d.severity),
      "message": d.message
   }
