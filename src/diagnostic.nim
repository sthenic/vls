import json

type
   Position* = object
      # Lines and columns are zero-based.
      line*, col*: int

   Range* = object
      start*, stop*: Position

   Severity* = enum
      ERROR = 1
      WARNING = 2
      INFO = 3
      HINT = 4

   Diagnostic* = object
      rng*: Range
      severity*: Severity
      message*: string


proc new_position*(line, col: int): Position =
   result.line = line
   result.col = col


proc new_diagnostic*(start, stop: Position, severity: Severity, message: string): Diagnostic =
   result.rng = Range(start: start, stop: stop)
   result.severity = severity
   result.message = message


proc `%`*(p: Position): JsonNode =
   result = %*{
      "line": p.line,
      "character": p.col
   }


proc `%`*(r: Range): JsonNode =
   result = %*{
      "start": r.start,
      "end": r.stop
   }


proc `%`*(d: Diagnostic): JsonNode =
   result = %*{
      "range": d.rng,
      "severity": d.severity,
      "message": d.message
   }
