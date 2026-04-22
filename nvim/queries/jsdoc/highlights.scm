; Local override of the default jsdoc highlights query.
; Keep upstream tag/type captures, and add fenced code block support so code
; lines are no longer rendered as plain comment text.
(tag_name) @keyword @nospell

(type) @type @nospell

[
  "{"
  "}"
  "["
  "]"
] @punctuation.bracket

[
  ":"
  "."
  "#"
  "~"
] @punctuation.delimiter

(path_expression
  "/" @punctuation.delimiter)

(identifier) @variable @nospell

(tag
  (tag_name) @_name
  (identifier) @function
  (#any-of? @_name "@callback" "@function" "@func" "@method"))

(tag
  (tag_name) @_name
  (identifier) @variable.parameter
  (#any-of? @_name "@param" "@arg" "@argument"))

(tag
  (tag_name) @_name
  (identifier) @property
  (#any-of? @_name "@prop" "@property"))

(tag
  (tag_name) @_name
  (identifier) @type
  (#eq? @_name "@typedef"))

"```" @markup.raw.block

(code_block_language) @label

; Provide a visible fallback when the injected language parser is unavailable.
(code_block_line) @markup.raw
