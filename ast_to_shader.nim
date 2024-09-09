import make_ast
import std/[hashes, algorithm]

var test_shader = """
texture GL_TEXTURE_2D ext1;
input a;
input c;
output vec4 d;
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

proc make_vertex_shader*(config_statements: seq[Statement], function_statements: seq[Statement]): string
proc make_vertex_shader*(statements: (seq[Statement], seq[Statement])): string =
    return make_vertex_shader(statements[0], statements[1])

proc make_vertex_shader*(config_statements: seq[Statement], function_statements: seq[Statement]): string =
    # proc sort_by_name_hash(s1, s2: Statement): int =
    #     cmp(hash(s1.name), hash(s2.name))
    # framebuffers_in.sort(sort_by_name_hash)
    # framebuffers_out.sort(sort_by_name_hash)

    # var framebuffers_in  : seq[Statement]
    var texture_ext       : seq[Statement]
    var struct_defs      : seq[Statement]
    var global_vars      : seq[Statement]
    var mesh_attributes  : seq[Statement]
    var between_vars     : seq[Statement]
    # var framebuffers_out : seq[Statement]

    for s in config_statements:
        case s.kind:
            # of pkTexInput    : framebuffers_in  &= s
            # of pkTexOutput   : framebuffers_out &= s
            of pkTexExternal : texture_ext      &= s
            of pkMeshAttrib  : mesh_attributes  &= s
            of pkBetween     : between_vars     &= s
            of pkStruct      : struct_defs      &= s
            of pkVar         : global_vars      &= s
            else:
                discard

    result &= "#version 330 core\n\n"

    # for st in texture_ext:
    #     echo(st.name)

    for st in struct_defs:
        result &= "struct " & st.name & " " & st.var_type & ";\n"
    if len(struct_defs) > 0:
        result &= "\n"

    for st in global_vars:
        result &= (if st.is_const: "const " else: "")
        result &= st.var_type & " " & st.name
        result &= (if len(st.value) > 0: " = " & st.value & ";\n" else: ";\n")
    if len(global_vars) > 0:
        result &= "\n"

    for st in texture_ext:
        result &= "uniform " & st.var_type & " " & st.name & ";\n"
        result &= "uniform sampler " & st.name & "_smp;\n"
    if len(texture_ext) > 0:
        result &= "\n"

    var i_attribute = 0
    for st in mesh_attributes:
        result &= "layout(location = " & $i_attribute & ") "
        result &= "in " & st.var_type & " " & st.name & ";\n"
        i_attribute += 1
    if len(mesh_attributes) > 0:
        result &= "\n"

    for st in between_vars:
        result &= "out " & st.var_type & " " & st.name & ";\n"
    if len(between_vars) > 0:
        result &= "\n"

    for st in function_statements:
        if st.function.kind == sfkOther:
            result &= st.var_type & "\n\n"

    for st in function_statements:
        if st.function.kind == sfkVertex:
            result &= st.var_type & "\n"

proc make_fragment_shader*(config_statements: seq[Statement], function_statements: seq[Statement]): string =
    # proc sort_by_name_hash(s1, s2: Statement): int =
    #     cmp(hash(s1.name), hash(s2.name))
    # framebuffers_in.sort(sort_by_name_hash)
    # framebuffers_out.sort(sort_by_name_hash)

    var framebuffers_in  : seq[Statement]
    var texture_ext       : seq[Statement]
    var struct_defs      : seq[Statement]
    var global_vars      : seq[Statement]
    # var mesh_attributes  : seq[Statement]
    var between_vars     : seq[Statement]
    var framebuffers_out : seq[Statement]

    for s in config_statements:
        case s.kind:
            of pkTexInput    : framebuffers_in  &= s
            of pkTexOutput   : framebuffers_out &= s
            of pkTexExternal : texture_ext      &= s
            # of pkMeshAttrib  : mesh_attributes  &= s
            of pkBetween     : between_vars     &= s
            of pkStruct      : struct_defs      &= s
            of pkVar         : global_vars      &= s
            else:
                discard

    result &= "#version 330 core\n\n"

    for st in struct_defs:
        result &= "struct " & st.name & " " & st.var_type & ";\n"
    if len(struct_defs) > 0:
        result &= "\n"

    for st in global_vars:
        result &= (if st.is_const: "const " else: "")
        result &= st.var_type & " " & st.name
        result &= (if len(st.value) > 0: " = " & st.value & ";\n" else: ";\n")
    if len(global_vars) > 0:
        result &= "\n"

    for st in framebuffers_in:
        result &= "uniform GL_TEXTURE_2D " & st.name & ";\n"
        result &= "uniform sampler " & st.name & "_smp;\n"
    if len(framebuffers_in) > 0:
        result &= "\n"

    for st in texture_ext:
        result &= "uniform " & st.var_type & " " & st.name & ";\n"
        result &= "uniform sampler " & st.name & "_smp;\n"
    if len(texture_ext) > 0:
        result &= "\n"

    for st in between_vars:
        result &= "in " & st.var_type & " " & st.name & ";\n"
    if len(between_vars) > 0:
        result &= "\n"

    var i_attribute = 0
    for st in framebuffers_out:
        result &= "layout(location = " & $i_attribute & ") "
        result &= "out " & st.var_type & " " & st.name & ";\n"
        i_attribute += 1
    if len(framebuffers_out) > 0:
        result &= "\n"

    for st in function_statements:
        if st.function.kind == sfkOther:
            result &= st.var_type & "\n\n"

    for st in function_statements:
        if st.function.kind == sfkFragment:
            result &= st.var_type & "\n"

# var (config_statements, function_statements) = parse_to_ast(test_shader)
# echo(make_vertex_shader(config_statements, function_statements))
# echo("------")
# echo(make_fragment_shader(config_statements, function_statements))
