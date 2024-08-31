import std/[strutils, tables, algorithm, sequtils] #, strbasics]

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
        pkMeshInput,
        pkTexInput,
        pkTexOutput
        pkTexExternal,
        pkUniform,
        pkMeshAttrib,
        pkBetween,
        pkFunction,
        pkInclude

    ShaderFunctionKind* = enum
        sfkVertex,
        sfkFragment,
        sfkOther

    Statement* = ref object
        name          *: string
        var_type      *: string
        case kind                   *: ShaderKeyword:
            of pkFunction: function *: ShaderFunction
            else: discard
        # layout_values *: seq[string] = @[]

    ShaderFunction* = ref object
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
    "INCL": pkInclude
}.toTable()
var function_kind_map: Table[string, ShaderFunctionKind] = {
    "VERTEX": sfkVertex,
    "VERT": sfkVertex,
    "FRAGMENT": sfkFragment,
    "FRAG": sfkFragment
}.toTable()

proc parse(shader: string): (seq[Statement], seq[Statement]) =
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
                if keyword != pkFunction:
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
                        defined_functions &= func_name
                        result[1] &= Statement(
                            name     : func_name,
                            var_type : keyword_data,
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

var (config_statements, function_statements) = parse(test_shader)

echo()
for s in config_statements:
    stdout.write(s.name)
    stdout.write(", ")
    stdout.write(s.var_type)
    stdout.write(", ")
    stdout.write(s.kind)
    stdout.write("\n")
echo()
for s in function_statements:
    stdout.write(s.name)
    stdout.write(", ")
    stdout.write(s.var_type)
    stdout.write(", ")
    stdout.write(s.kind)
    stdout.write(", ")
    stdout.write(s.function.kind)
    stdout.write(", ")
    stdout.write($s.function.calls)
    stdout.write("\n\n")
