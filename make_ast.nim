import std/[strutils, tables, algorithm, sequtils, strbasics]

var test_shader = """
texture GL_TEXTURE_2D ext1;
input a;
input c;
output d;
uniform float foo;
mesh vertex_color;
attrib vec4 position;
attrib vec4 color0;
between vec4 color;
var int foo 10;
var float foo2 = 5;
const int bar 15;
const float bar2 = -20;
struct TypeWithDecl {
int foo;
vec3 bar;
} typeWithDecl;
struct Type {
    float x;
    float y;
    float z;
};

function float a(in float x) {
    return 1.f - x;
}

function float b(in float x) {
    return a(2.f * x) - x;
}

function float c(in float x) {
    return b(x - 1.f) + a(1.f - x);
}

function void vertex() { // unlike regular glsl, use function keyword because i don't want to spend the time to write a more complex transpiler
    gl_Position = position;
    color = color0;
}

function void fragment() {
    d=vec4(color.r, c(color.g), color.b, color.a);
}
"""

type
    ShaderKeyword* = enum
        pkInclude,
        pkMeshInput,
        pkTexInput,
        pkTexOutput
        pkTexExternal,
        pkVar,
        pkUniform,
        pkMeshAttrib,
        pkBetween,
        pkFunction,
        pkStruct,

    ShaderFunctionKind* = enum
        sfkVertex,
        sfkFragment,
        sfkOther

    Statement* = ref object
        name          *: string
        var_type      *: string
        case kind                   *: ShaderKeyword:
            of pkFunction: function *: ShaderFunction
            of pkVar:
                value    *: string
                is_const *: bool
            else: discard
        # layout_values *: seq[string] = @[]

    ShaderFunction* = ref object # was separate to handle calls as graph, should be refactored into Statement
        name  *: string
        kind  *: ShaderFunctionKind
        calls *: seq[string]

var keyword_map: Table[string, ShaderKeyword] = {
    "MESH": pkMeshInput,
    "INPUT": pkTexInput,
    "IN": pkTexInput,
    "OUTPUT": pkTexOutput,
    "OUT": pkTexOutput,
    "TEXTURE": pkTexExternal,
    "TEX": pkTexExternal,
    "UNIFORM": pkUniform,
    "ATTRIBUTE": pkMeshAttrib,
    "ATTRIB": pkMeshAttrib,
    "ATTR": pkMeshAttrib,
    "BETWEEN": pkBetween,
    "FUNCTION": pkFunction,
    "FUNC": pkFunction,
    "FUN": pkFunction,
    "FN": pkFunction,
    "PROC": pkFunction,
    "PROCEDURE": pkFunction,
    "INCLUDE": pkInclude,
    "INCL": pkInclude,
    "VAR": pkVar,
    "CONST": pkVar, # handled as part of state of var ast obj
    "STRUCT": pkStruct, # make separate line with variable decl if you want const
}.toTable()
var function_kind_map: Table[string, ShaderFunctionKind] = {
    "VERTEX": sfkVertex,
    "VERT": sfkVertex,
    "FRAGMENT": sfkFragment,
    "FRAG": sfkFragment
}.toTable()

proc parse_to_ast*(shader: string): (seq[Statement], seq[Statement]) =
    var sc_brace   = 0
    var sc_paren   = 0
    var sc_bracket = 0
    # var word_buffer = ""
    var is_line_comment = false
    var is_span_comment = false
    var on_first_word_of_line = true
    var line_has_non_alpha = false
    # var skip_char = false

    var has_keyword = false
    var keyword_buffer = ""
    var keyword: ShaderKeyword
    var keyword_data = ""
    # var config_statements: seq[Statement]
    # var function_statements: seq[Statement]
    var function_buffer = ""
    var function_calls: seq[string]
    var in_func_body = false
    var defined_functions: seq[string]
    var is_var_const = false
    var var_type = ""
    var var_name = ""
    var var_value = ""
    var var_has_type = false
    var var_has_name = false
    var var_value_past_equals = false
    var struct_at_var_name = false
    var struct_at_body = false
    var struct_var_decl = ""
    var struct_type_name = ""

    block: # so i can be reused elsewhere
        var i = 0
        while i < len(shader):
            # skip_char = false
            if not is_line_comment:
                if not (i == len(shader)):
                    is_line_comment = shader[i] == '/' and shader[i + 1] == '/'
            else:
                is_line_comment = shader[i] != '\n'
            if is_line_comment: # early skip to avoid brace counters being set during comments
                i += 1
                continue
            if shader[i] == '{':
                sc_brace += 1
                # skip_char = true
            elif shader[i] == '}':
                sc_brace -= 1
                # skip_char = true
            elif shader[i] == '(':
                sc_paren += 1
                # skip_char = true
            elif shader[i] == ')':
                sc_paren -= 1
                # skip_char = true
            elif shader[i] == '[':
                sc_bracket += 1
                # skip_char = true
            elif shader[i] == ']':
                sc_bracket -= 1
                # skip_char = true
            if sc_brace < 0: # handle interleaved brace types
                echo("unexpected extra closing brace")
                quit(1)
            if sc_paren < 0:
                echo("unexpected extra closing paren")
                quit(1)
            if sc_bracket < 0:
                echo("unexpected extra closing bracket")
                quit(1)
            # if skip_char:
            #     stdout.write(shader[i])
            #     i += 1
            #     continue
            if not has_keyword:
                if not shader[i].isSpaceAscii():
                    line_has_non_alpha = true
                if line_has_non_alpha and on_first_word_of_line and shader[i].isSpaceAscii():
                    on_first_word_of_line = false
                    if keyword_buffer.toUpperAscii() in keyword_map:
                        has_keyword = true
                        keyword = keyword_map[keyword_buffer.toUpperAscii()]
                        if keyword_buffer.toUpperAscii() == "CONST":
                            is_var_const = true
                        keyword_data = ""
                        # stdout.write("<<<")
                    keyword_buffer = ""
                    # stdout.write(".")
                elif shader[i] == '\n': # shader[i] == ';' or (shader[i] == '\n' and sc_brace == 0):
                    on_first_word_of_line = true
                    line_has_non_alpha = false
                    # stdout.write("^")
                # stdout.write(shader[i])
                if on_first_word_of_line and shader[i] != '\n':
                    keyword_buffer &= shader[i]
            else:
                # case keyword:
                #     of pkMeshInput:
                #         discard
                #     of pkTexInput:
                #         discard
                #     of pkTexOutput:
                #         discard
                #     of pkTexExternal:
                #         discard
                #     of pkUniform:
                #         discard
                #     of pkMeshAttrib:
                #         discard
                #     of pkBetween:
                #         discard
                #     of pkFunction:
                #         discard
                # stdout.write(shader[i])
                if keyword == pkVar:
                    if shader[i] == ';':
                        var_name.strip()
                        var_type.strip()
                        var_value.strip()
                        result[0] &= Statement(
                            name     : var_name,
                            var_type : var_type,
                            kind     : pkVar,
                            value    : var_value,
                            is_const : is_var_const,
                        )
                        # echo("type:  ", var_type)
                        # echo("name:  ", var_name)
                        # echo("value: ", var_value)
                        # echo("const: ", is_var_const)
                        is_var_const = false
                        has_keyword = false
                        var_has_type = false
                        var_has_name = false
                        var_value_past_equals = false
                        keyword_data = ""
                        var_type = ""
                        var_name = ""
                        var_value = ""
                    else:
                        if var_has_name and not (shader[i] == '=' or shader[i] == ' '):
                            var_value_past_equals = true
                        if var_has_name: # append first to have trailing spaces rather than leading
                            if var_value_past_equals:
                                var_value &= shader[i]
                        elif var_has_type:
                            var_name &= shader[i]
                        else:
                            var_type &= shader[i]
                        if var_has_type and (shader[i] == ' ' or shader[i] == '=' or shader[i] == ';'):
                            var_has_name = true
                        if shader[i] == ' ': # flipped order to change above state next iteration
                            var_has_type = true
                        # keyword_data &= shader[i]
                elif keyword == pkStruct:
                    if (not struct_at_body) and sc_brace == 1 and shader[i] == '{': # sc_brace will have been incremented by now
                        struct_at_body = true
                    if not struct_at_body:
                        struct_type_name &= shader[i]
                    elif not struct_at_var_name:
                        keyword_data &= shader[i]
                    else:
                        struct_var_decl &= shader[i]
                    if sc_brace == 0:
                        if shader[i] == '}':
                            struct_at_var_name = true
                        elif shader[i] == ';':
                            struct_type_name.strip()
                            keyword_data.strip()
                            keyword_data.strip(chars = {';'})
                            keyword_data = keyword_data.replace("\n", " ")
                            var struct_data = ""
                            var last_was_space = false
                            for c in keyword_data:
                                if c == ' ':
                                    if not last_was_space:
                                        struct_data &= c
                                    last_was_space = true
                                else:
                                    last_was_space = false
                                    struct_data &= c
                            struct_var_decl.strip()
                            struct_var_decl.strip(chars = {';'})
                            result[0] &= Statement(
                                name     : struct_type_name,
                                var_type : struct_data,
                                kind     : pkStruct
                            )
                            if len(struct_var_decl) > 0:
                                result[0] &= Statement(
                                    name     : struct_var_decl,
                                    var_type : struct_type_name,
                                    kind     : pkVar,
                                    value    : "",
                                    is_const : false,
                                )
                            # echo(struct_type_name)
                            # echo(keyword_data)
                            # echo(struct_var_decl)
                            has_keyword = false
                            struct_at_var_name = false
                            struct_at_body = false
                            keyword_data = ""
                            struct_var_decl = ""
                            struct_type_name = ""
                elif keyword != pkFunction:
                    keyword_data &= shader[i]
                    if shader[i] == ';':
                        # stdout.write(">>>")
                        # keyword_data.strip(trailing = false, chars = {';'})
                        # stdout.write(keyword_data)
                        var split_data = keyword_data.replace(";", "").split(" ", 1)
                        result[0] &= Statement(
                            name     : if len(split_data) > 1 : split_data[1] else: split_data[0],
                            var_type : if len(split_data) > 1 : split_data[0] else: "",
                            kind     : keyword
                        )

                        has_keyword = false
                        keyword_data = ""
                else:
                    keyword_data &= shader[i]
                    function_buffer &= shader[i]
                    if shader[i] == '{':
                        in_func_body = true
                    if in_func_body and shader[i] == '(':
                        function_buffer.delete((len(function_buffer) - 1) ..< len(function_buffer))
                        # stdout.write("[")
                        # stdout.write(function_buffer)
                        # stdout.write("]")
                        function_calls &= function_buffer
                        function_buffer = ""
                    elif not shader[i].isAlphaNumeric():
                        function_buffer = ""
                    if shader[i] == '}' and sc_brace == 0:
                        # stdout.write(">>>")
                        # keyword_data.strip(trailing = false, chars = {';'})
                        # stdout.write(keyword_data)
                        var func_name = keyword_data.split("(", 1)[0].split(" ")[^1]
                        var main_rename = keyword_data
                        if func_name.toUpperAscii() in function_kind_map:
                            if function_kind_map[func_name.toUpperAscii()] != sfkOther:
                                main_rename = ""
                                var at_func_name = false
                                var after_func_name = false
                                for c in keyword_data:
                                    if not at_func_name and c == ' ':
                                        main_rename &= " main"
                                        at_func_name = true
                                    elif c == '(':
                                        after_func_name = true
                                    if not at_func_name:
                                        main_rename &= c
                                    elif after_func_name:
                                        main_rename &= c
                        defined_functions &= func_name
                        result[1] &= Statement(
                            name     : func_name,
                            var_type : main_rename,
                            kind     : pkFunction,
                            function : ShaderFunction(
                                name: func_name,
                                kind : if func_name.toUpperAscii() in function_kind_map:
                                            function_kind_map[func_name.toUpperAscii()]
                                        else:
                                            sfkOther,
                                calls: function_calls
                            )
                        )

                        has_keyword = false
                        keyword_data = ""
                        function_buffer = ""
                        function_calls = @[]
                        in_func_body = false
            i += 1

    for s in result[1]:
        var new_calls: seq[string]
        for call in s.function.calls:
            if call in defined_functions:
                new_calls &= call
        s.function.calls = new_calls.deduplicate()
        for call in s.function.calls:
            if call.toUpperAscii() in ["VERTEX", "VERT", "FRAGMENT", "FRAG"]:
                echo("invalid function to call " & call)
                quit(1)

# var (config_statements, function_statements) = parse_to_ast(test_shader)

# echo()
# for s in config_statements:
#     stdout.write(s.name)
#     stdout.write(", ")
#     stdout.write(s.var_type)
#     if s.kind == pkVar:
#         stdout.write(", ")
#         stdout.write(s.value)
#         stdout.write(", ")
#         stdout.write(if s.is_const: "const" else: "var")
#     stdout.write(", ")
#     stdout.write(s.kind)
#     stdout.write("\n")
# echo()
# for s in function_statements:
#     stdout.write(s.name)
#     stdout.write(", ")
#     stdout.write(s.var_type)
#     stdout.write(", ")
#     stdout.write(s.kind)
#     stdout.write(", ")
#     stdout.write(s.function.kind)
#     stdout.write(", ")
#     stdout.write($s.function.calls)
#     stdout.write("\n\n")
