; Inject fenced code blocks inside JSDoc comments using the declared language.
; The grammar exposes each code line as a separate node, so combine them into a
; single injected document.
(code_block
  (code_block_language) @injection.language
  (code_block_line) @injection.content+
  (#set! injection.combined))
