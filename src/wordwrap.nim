import strutils
import unicode

# Borrowed/improved word wrapping implementation from Nim/devel until these are
# released in a compatible state (or not).
type WordWrapState = enum
   AfterNewline
   MiddleOfLine


proc olen(s: string): int =
   var i = 0
   while i < len(s):
      inc(result)
      let L = grapheme_len(s, i)
      inc(i, L)


proc wrap_words*(s: string, max_line_width = 80, split_long_words = true,
                 seps: set[char] = Whitespace,
                 new_line = "\n"): string {.noSideEffect.} =
   ## Word wraps `s`.
   result = new_string_of_cap(len(s) + len(s) shr 6)
   var state: WordWrapState
   var space_rem = max_line_width
   var last_sep, indent = ""
   for word, is_sep in tokenize(s, seps):
      let wlen = olen(word)
      if is_sep:
         # Process the whitespace 'word', adding newlines as needed and keeping
         # any trailing non-newline whitespace characters as the indentation
         # level.
         for c in word:
            if c in NewLines:
               add(result, new_line)
               last_sep.set_len(0)
               indent.set_len(0)
               space_rem = max_line_width
               state = AfterNewline
            else:
               case state
               of AfterNewline:
                  add(indent, c)
                  space_rem = max_line_width - len(indent)
               of MiddleOfLine:
                  add(last_sep, c)
                  dec(space_rem) # TODO: Treat tabs differently?
      elif wlen > space_rem:
         if split_long_words and wlen > max_line_width - len(indent):
            case state
            of AfterNewline:
               result.add(indent)
            of MiddleOfLine:
               result.add(last_sep)
               last_sep.set_len(0)

            var i = 0
            while i < len(word): # TODO: Is len(word) correct here?
               if space_rem <= 0:
                  space_rem = max_line_width - len(indent)
                  result.add(new_line & indent)
               dec(space_rem)
               let L = grapheme_len(word, i)
               for j in 0..<L:
                  result.add(word[i+j])
               inc(i, L)
         else:
            space_rem = max_line_width - len(indent) - len(word)
            result.add(new_line & indent & word)
            last_sep.set_len(0)

         # TODO: Is this ok in the case when the word get broken to exactly 80 chars?
         state = MiddleOfLine
      else:
         # TODO: Think about what happens to space_rem if AfterNewLine. Is it
         # already decremented with the indent level?
         case state
         of AfterNewline:
            result.add(indent)
         of MiddleOfLine:
            result.add(last_sep)
            last_sep.set_len(0)

         space_rem = space_rem - len(word)
         result.add(word)
         state = MiddleOfLine

