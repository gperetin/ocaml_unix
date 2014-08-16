type unr_op = UMINUS | NOT
type bin_op = PLUS | MINUS | MULT | DIV | MOD
              | EQUAL | LESS | LESSEQ | GREAT | GREATEQ | DIFF
              | AND | OR;;

type expression = 
    | ExpInt of int
    | ExpVar of string
    | ExpStr of string
    | ExpUnr of unr_op * expression
    | ExpBin of expression * bin_op * expression;;

type command =
    | Rem of string
    | Goto of int
    | Print of expression
    | Input of string
    | If of expression * int
    | Let of string * expression;;

type line = { num: int; cmd: command }
type program = line list

type phrase = Line of line | List | Run | PEnd

(* Operator precedence. Each operation gets an integer (priority),
 * operators with higher value get applied first. *)
let priority_uop = function NOT -> 1 | UMINUS -> 7
let priority_binop = function
    | MULT | DIV -> 6
    | PLUS | MINUS -> 5
    | MOD -> 4
    | EQUAL | LESS | LESSEQ | GREAT | GREATEQ | DIFF ->3
    | AND | OR -> 2;;

let pp_binop = function
    | PLUS -> "+" | MULT -> "*" | MOD -> "%" | MINUS -> "-"
    | DIV -> "/" | EQUAL -> " = " | LESS -> " < "
    | LESSEQ -> " <= " | GREAT -> " > " | GREATEQ -> " >= "
    | DIFF -> " <> " | AND -> " & " | OR -> " | ";;

let pp_unop = function
    | UMINUS -> "-" | NOT -> "!"

let parenthesis x = "(" ^ x ^ ")"

(* Next 3 functions are used for pretty-printing *)
let pp_expression =
    (* Pretty-print left subtree. pr is operator priority (so we know if
        * we need to print parenthesis) *)
    let rec ppl pr = function
        | ExpInt n -> (string_of_int n)
        | ExpVar v -> v
        | ExpStr s -> "\"" ^ s ^ "\""
        | ExpUnr (op, e) ->
                let res = (pp_unop op) ^ (ppl (priority_uop op) e)
                in if pr=0 then res else parenthesis res
        | ExpBin (e1, op, e2) ->
                let pr2 = priority_binop op
                in let res = (ppl pr2 e1) ^ (pp_binop op) ^ (ppr pr2 e2)
                in if pr2 >= pr then res else parenthesis res
    and ppr pr exp = match exp with
    | ExpBin (e1, op, e2) ->
        let pr2 = priority_binop op
        in let res = (ppl pr2 e1) ^ (pp_binop op) ^ (ppr pr2 e2)
        in if pr2 > pr then res else parenthesis res
    | _ -> ppl pr exp
    in ppl 0;;

let pp_command = function
    | Rem s -> "REM " ^ s
    | Goto n -> "GOTO " ^ (string_of_int n)
    | Print e -> "PRINT " ^ (pp_expression e)
    | Input v -> "INPUT " ^ v
    | If (e,n) -> "IF " ^ (pp_expression e) ^ " THEN " ^ (string_of_int n)
    | Let (v, e) -> "LET " ^ v ^ " = " ^ (pp_expression e);;

let pp_line l = (string_of_int l.num) ^ " " ^ (pp_command l.cmd);;


(* Lexing *)
type lexeme =
    | Lint of int
    | Lident of string
    | Lsymbol of string
    | Lstring of string
    | Lend;;

(* String currently being lexed. current points to the position after
 * which the lexing hasn't been done yet *)
type string_lexer = {string:string; mutable current:int; size:int};;

let init_lex s = {string=s; current=0; size=String.length s};;
let forward cl = cl.current <- cl.current + 1;;
let forward_n cl n = cl.current <- cl.current + n;;

(* Extract lexeme from cl using predicate pred *)
let extract pred cl =
    let st = cl.string and pos = cl.current in

    (* This function goest through the string st and moves pointer forward
     * while element at current position satisfies pred. It returns last
     * position of the pointer *)
    let rec ext n = if n < cl.size && (pred st.[n]) then ext(n+1) else n in
    let res = ext pos
    (* Move pointer into the string, and extract portion of the string
     * between pos and res *)
    in cl.current <- res; String.sub cl.string pos (res-pos);;

let extract_int =
    let is_int = function '0'..'9' -> true | _ -> false
    in function cl -> int_of_string (extract is_int cl);;

let extract_ident =
    let is_alpha_num = function
        | 'a'..'z' | 'A'..'Z' | '0'..'9' | '_' -> true
        | _ -> false
    (* Return partially applied function that takes in just one argument,
     * string_lexer to extract from *)
    in extract is_alpha_num;;

exception LexerError;;

let rec lexer cl =
    let lexer_char c = match c with
    ' ' | '\t' -> forward cl; lexer cl
    | 'a'..'z' | 'A'..'Z' -> Lident (extract_ident cl)
    | '0'..'9' -> Lint (extract_int cl)
    | '"' -> forward cl;
        let res = Lstring (extract ((<>) '"') cl)
        in forward cl; res
    | '+' | '-' | '*' | '/' | '%' | '&' | '|' | '!' | '=' | '(' | ')' ->
            forward cl; Lsymbol (String.make 1 c)
    | '<' | '>' -> forward cl;
        if cl.current >= cl.size then Lsymbol (String.make 1 c)
        else let cs = cl.string.[cl.current]
            in (match(c, cs) with
            | ('<', '=') -> forward cl; Lsymbol "<="
            | ('>', '=') -> forward cl; Lsymbol ">="
            | ('<', '>') -> forward cl; Lsymbol "<>"
            | _ -> Lsymbol (String.make 1 c) )
    | _ -> raise LexerError
    in
        if cl.current >= cl.size then Lend
        else lexer_char cl.string.[cl.current];;
