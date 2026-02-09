;; extends

; Method Definitions (Private)
((method_declaration 
  name: (field_identifier) @method.private)
 (#match? @method.private "^[a-z]"))

; Method Calls (Private)
((call_expression 
  function: (selector_expression 
    field: (field_identifier) @method.call.private))
 (#match? @method.call.private "^[a-z]"))

; Function Definitions (Private)
((function_declaration
  name: (identifier) @function.private)
 (#match? @function.private "^[a-z]"))

; Function Calls (Private)
((call_expression
  function: (identifier) @function.call.private)
 (#match? @function.call.private "^[a-z]"))
