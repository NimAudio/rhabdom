import std/[strutils, tables, algorithm, sequtils, strbasics]

var test_shader = """
texture GL_TEXTURE_2D ext1;
input a;
input c;
// when not present, should output ast for: output vec4 frag_color;
output vec4 d;
output vec4 e;
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

enable foo bar bat;
enable
one
two three,
four,five;
disable abc,def,       ghi     jkl;

clear 0.0, 1.0, 0.0, 1.0;
clear d, 1.0 0.0 0.0 1.0;
clear 0.0 0.0 0.0 0.0 1.0 2.0 e;
clear 1.0 0.0 1.0 0.0, f;

scale 0.25;
scale 2x;
scale 400px, 800px;

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
        pkClearColor,  #TODO implement
        pkEnable,      #TODO implement
        pkResScale     #TODO implement

    ShaderFunctionKind* = enum
        sfkVertex,
        sfkFragment,
        sfkOther

    Statement* = ref object
        name      *: string
        var_type  *: string
        location  *: uint32
        case kind *: ShaderKeyword:
            of pkFunction:
                function *: ShaderFunction
            of pkVar:
                value    *: string
                is_const *: bool
            of pkClearColor:
                color *: array[4, float32]
            of pkEnable:
                enable *: bool # true enables, false disables
                settings *: seq[string]
            else: discard
        # layout_values *: seq[string] = @[]

    ShaderFunction* = ref object # was separate to handle calls as graph, should be refactored into Statement
        name  *: string
        kind  *: ShaderFunctionKind
        calls *: seq[string]

proc `$`*(s: Statement): string =
    case s.kind:
        of pkInclude:
            result &= "INCL "
        of pkMeshInput:
            result &= "MESH "
        of pkTexInput:
            result &= "IN "
        of pkTexOutput:
            result &= "OUT "
        of pkTexExternal:
            result &= "TEX "
        of pkVar:
            result &= "VAR "
        of pkUniform:
            result &= "UNI "
        of pkMeshAttrib:
            result &= "ATTR "
        of pkBetween:
            result &= "BTW "
        of pkFunction:
            result &= "FUNC "
        of pkStruct:
            result &= "STRC "
        of pkClearColor:
            result &= "CLCOLOR "
        of pkEnable:
            if s.enable:
                result &= "ENABLE "
            else:
                result &= "DISABLE "
        of pkResScale:
            result &= "SCALE "
    result &= s.name

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
    "CLEAR": pkClearColor,
    "COLOR": pkClearColor,
    "ENABLE": pkEnable,
    "DISABLE": pkEnable,
    "SCALE": pkResScale,
    "RESOLUTION": pkResScale,
    "RES": pkResScale,
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
    # var line_past_indent = false
    # var char_counter = 0

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

    var is_enable_disable = false
    var enable_seq: seq[string]
    var enable_buffer = ""
    var last_was_separator = false
    var color_array: array[4, float32]
    var color_index = 0
    var clear_color_name = ""

    # var num_spaces = 0
    # if shader.startsWith(" "):
    #     for i in 0 ..< len(shader):
    #         if shader[i] == ' ':
    #             num_spaces += 1
    #         else:
    #             break
    # #     shader = shader.dedent(num_spaces)
    # echo(num_spaces)

    block: # so i can be reused elsewhere
        var i = 0
        while i < len(shader):
            # skip_char = false
            # if (not line_past_indent) and shader[i] != ' ' and shader[i] != '\n':
            #     stdout.write('.')
            #     line_past_indent = true
            # if not line_past_indent:
            #     i += 1
            #     continue
            # if shader[i] == ';':
            #     stdout.write('!')
            #     line_past_indent = false
            # if char_counter < num_spaces:
            #     i += 1
            #     char_counter += 1
            #     continue
            # if shader[i] == ';':
            #     stdout.write("<")
            #     stdout.write(char_counter)
            #     stdout.write(">")
            #     char_counter = 0
            #     stdout.write("<")
            #     stdout.write(num_spaces)
            #     stdout.write(">")
            # stdout.write(shader[i])
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
                        # echo(keyword)
                        if keyword_buffer.toUpperAscii() == "CONST":
                            is_var_const = true
                        if keyword_buffer.toUpperAscii() == "DISABLE":
                            is_enable_disable = true
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
                elif keyword == pkEnable:
                    if shader[i] == ';':
                        enable_seq &= enable_buffer
                        enable_buffer = ""
                        # echo(enable_seq)
                        result[0] &= Statement(
                            name     : if is_enable_disable: "Disable" else: "Enable",
                            var_type : "",
                            kind     : pkEnable,
                            enable   : not is_enable_disable,
                            settings : enable_seq
                        )
                        enable_seq = @[]
                        has_keyword = false
                        last_was_separator = false
                        keyword_data = ""
                    elif shader[i] != ',' and shader[i] != ' ' and shader[i] != '\n':
                        last_was_separator = false
                        enable_buffer &= shader[i]
                    elif not last_was_separator:
                        last_was_separator = true
                        enable_seq &= enable_buffer
                        enable_buffer = ""
                elif keyword == pkClearColor:
                    if shader[i] == ';':
                        try:
                            var value = float32(parseFloat(enable_buffer))
                            if color_index < 4:
                                color_array[color_index] = value
                            color_index += 1
                        except ValueError:
                            clear_color_name = enable_buffer
                        enable_buffer = ""
                        # echo(enable_seq)
                        result[0] &= Statement(
                            name     : clear_color_name,
                            var_type : "",
                            kind     : pkClearColor,
                            color    : color_array
                        )
                        enable_seq = @[]
                        has_keyword = false
                        last_was_separator = false
                        keyword_data = ""
                        clear_color_name = ""
                        color_index = 0
                    elif shader[i] != ',' and shader[i] != ' ' and shader[i] != '\n':
                        last_was_separator = false
                        enable_buffer &= shader[i]
                    elif not last_was_separator:
                        last_was_separator = true
                        try:
                            var value = float32(parseFloat(enable_buffer))
                            if color_index < 4:
                                color_array[color_index] = value
                            color_index += 1
                        except ValueError:
                            clear_color_name = enable_buffer
                        enable_buffer = ""
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

    var tex_loc = 0
    var has_output = false
    var has_scale = false
    for s in result[0]:
        if s.kind == pkTexOutput:
            has_output = true
        elif s.kind == pkResScale:
            has_scale = true
        elif s.kind == pkTexExternal:
            s.location = uint32(tex_loc)
            tex_loc += 1
    if not has_output:
        result[0] &= Statement(
                            name     : "frag_color",
                            var_type : "vec4",
                            kind     : pkTexOutput
                        )
    if not has_scale:
        result[0] &= Statement(
                            name     : "1.0",
                            var_type : "",
                            kind     : pkResScale
                        )


proc parse_all*(strings: openArray[string]): seq[(seq[Statement], seq[Statement])] =
    for f in strings:
        result &= parse_to_ast(f)


proc parse_all_config*(strings: openArray[string]): seq[seq[Statement]] =
    for f in strings:
        result &= parse_to_ast(f)[0]

proc all_configs*(both: seq[(seq[Statement], seq[Statement])]): seq[seq[Statement]] =
    for s in both:
        result &= s[0]


proc parse_all_function*(strings: openArray[string]): seq[seq[Statement]] =
    for f in strings:
        result &= parse_to_ast(f)[1]

proc all_functions*(both: seq[(seq[Statement], seq[Statement])]): seq[seq[Statement]] =
    for s in both:
        result &= s[1]

# var (config_statements, function_statements) = parse_to_ast(test_shader)

# echo()
# for s in config_statements:
#     stdout.write(s.kind)
#     stdout.write(", n:")
#     stdout.write(s.name)
#     stdout.write(", t:")
#     stdout.write(s.var_type)
#     if s.kind == pkVar:
#         stdout.write(", ")
#         stdout.write(s.value)
#         stdout.write(", ")
#         stdout.write(if s.is_const: "const" else: "var")
#     elif s.kind == pkEnable:
#         stdout.write(", ")
#         stdout.write(s.enable)
#         stdout.write(", ")
#         stdout.write(s.settings)
#     elif s.kind == pkClearColor:
#         stdout.write(", ")
#         stdout.write(s.color)
#     stdout.write("\n")
# echo()
# for s in function_statements:
#     stdout.write(s.kind)
#     stdout.write(", ")
#     stdout.write(s.function.kind)
#     stdout.write(", ")
#     stdout.write(s.name)
#     stdout.write(", ")
#     stdout.write(s.var_type)
#     stdout.write(", ")
#     stdout.write($s.function.calls)
#     stdout.write("\n\n")
