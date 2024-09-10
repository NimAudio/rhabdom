import std/[strutils, tables, algorithm]
import make_ast

var files = [
"""
texture ext1;
output a;
""",
"""
input a;
output b;
""",
"""
texture ext1;
input a;
input c;
output d;
uniform float foo;
mesh vertex_color;
attrib vec4 position;
attrib vec4 color0;
between vec4 color;

void main() {
    gl_Position = position;
    color = color0;
}

void main() {
    d = color;
}
""",
# """
# // complex loop
# texture d;
# texture i;
# output j;
# """,
# """
# texture j;
# output k;
# """,
# """
# texture k;
# output i;
# """,
# """
# texture b;
# // should be excluded
# """,
"""
texture ext2;
input b;
input d;
output e;
""",
"""
input b;
output c;
output m;
""",
"""
input m;
input e;
output f;
""",
# """
# // simple loop
# texture c;
# texture g;
# output h;
# """,
# """
# texture h;
# output g;
# """
]

type Tokenized* = object
    inputs_named *: seq[string]
    output_named *: seq[string]
    inputs_id    *: seq[int]
    output_id    *: int
    position     *: int

proc `$`*(t: Tokenized): string =
    result &= "AT: " & $t.position & " ID: " & $t.output_id & " IN: " & $t.inputs_named & " " & $t.inputs_id & " OUT: " & $t.output_named

proc loop_check(tokenized: seq[Tokenized], s_id, checkfor: int): bool =
    # echo(s_id, " ", checkfor, " ", tokenized[s_id].inputs_id)
    if len(tokenized[s_id].inputs_id) == 0:
        # echo("no inputs")
        return false
    if checkfor in tokenized[s_id].inputs_id:
        # echo("has checkfor in inputs")
        return true
    for input in tokenized[s_id].inputs_id:
        if tokenized.loop_check(input, checkfor):
            return true
    return false

proc echo_position(tokenized: seq[Tokenized]) =
    # stdout.write("[")
    # for i in 0 ..< len(result):
    #     stdout.write(result[i].position)
    #     if i < (len(result) - 1):
    #         stdout.write(", ")
    # stdout.write("]")
    # stdout.write("\n")
    for s in tokenized:
        # stdout.write(s.output_id)
        # stdout.write(" ")
        stdout.write("--")
    for shader in tokenized:
        stdout.write(shader.position)
    stdout.write("\n")
    for i in 0 ..< len(tokenized):
        for s in tokenized:
            if s.position == i:
                stdout.write(s.output_id)
            else:
                stdout.write(".")
            stdout.write(" ")
        stdout.write("\n")
    # for s in result:
    #     stdout.write(s.output_id)
    #     stdout.write(" ")
    # stdout.write("\n")

proc serialize_shader_list*(shaders: seq[seq[Statement]]): seq[Tokenized] =
    # var result: seq[Tokenized]
    var output_name_to_id: Table[string, int]

    block:
        discard
        # block: # make i and j not stick around
        #     var i = 0
        #     var j = 0
        #     for file in shaders:
        #         var shader: Tokenized
        #         var has_output = false
        #         var split_by_newline = file.split("\n")
        #         var decommented: string
        #         for s in split_by_newline:
        #             if not s.startswith("//"):
        #                 decommented &= s & "\n"
        #         for line in decommented.split("\n"):
        #             var split_line = line.split(" ")
        #             if (split_line[0] == "texture") or (split_line[0] == "input"):
        #                 shader.inputs_named &= split_line[1].replace(";", "")
        #             elif split_line[0] == "output":
        #                 # echo(split_line, has_output)
        #                 shader.output_named &= split_line[1].replace(";", "")
        #                 output_name_to_id[split_line[1].replace(";", "")] = i
        #                 shader.output_id = i
        #                 has_output = true
        #                 # echo(shader.output_id, shader.output_named)
        #             # else:
        #             if len(line) > 0:
        #                 shader.shader_text &= line & "\n"
        #         if has_output:
        #             i += 1
        #         if has_output:
        #             shader.position = j
        #             j += 1
        #             # echo($shader.inputs_named & "  ->  " & $shader.output_named & " at: " & $shader.position & " id: " & $shader.output_id)
        #             result &= shader

    block: # make i and j not stick around
        var i = 0
        var j = 0
        for statements in shaders:
            var shader: Tokenized
            var has_output = false
            for s in statements:
                if s.kind == pkTexInput:
                    shader.inputs_named &= s.name
                elif s.kind == pkTexOutput:
                    # echo(split_line, has_output)
                    shader.output_named &= s.name
                    output_name_to_id[s.name] = i
                    shader.output_id = i
                    has_output = true
            if has_output:
                i += 1
            if has_output:
                shader.position = j
                j += 1
                result &= shader
    # for tok in result:
    #     echo(tok)

    var has_source: seq[string]
    var no_source: seq[string]
    var used: seq[string]
    var unused: seq[string]

    for shader in result:
        for output in shader.output_named:
            if output in has_source:
                echo("redefinition of " & output)
            else:
                has_source &= output

    for shader in result:
        for input in shader.inputs_named:
            if input notin has_source and input notin no_source:
                no_source &= input

    for shader in result:
        for input in shader.inputs_named:
            if input notin used:
                used &= input

    for shader in result:
        for output in shader.output_named:
            if output notin used:
                unused &= output

    # echo(has_source)
    # echo(no_source)
    # echo(used)
    # echo(unused)

    # if len(unused) != 1:
    #     echo("graph has " & $len(unused) & " outputs, one must be selected")
    # else:
    #     echo("only has one output, good")

    # if len(unused) > 0:
    #     var output = unused[0]

    for shader in result.mitems:
        for input in shader.inputs_named:
            if input in has_source:
                # echo(input, output_name_to_id[input])
                shader.inputs_id &= output_name_to_id[input]

    # for shader in result:
    #     echo("in " & $shader.inputs_named & " " & $shader.inputs_id)
    #     echo("out " & $shader.output_named & " " & $shader.output_id)
    #     echo("at " & $shader.position)

    var in_loop: seq[int]

    for i in 0 ..< len(result):
        if result.loop_check(i, i):
            echo("loop detected containing source of " & $result[i].output_named)
            if i notin in_loop:
                in_loop &= i
            # result.del(i)
        # echo(i, loop_check(i, i))

    in_loop.sort()
    in_loop.reverse()

    # for shader in result:
    #     echo(shader.output_named, " ", shader.output_id, " ", shader.inputs_id)

    for s_id in in_loop:
        echo("deleting source of " & $result[s_id].output_named)
        for s in result.mitems():
            for input in s.inputs_id.mitems():
                if input == s_id:
                    echo("shader source " & $s.output_named & " depends on loop")
                    # should delete
                elif input > s_id:
                    input -= 1
            if s.output_id > s_id:
                s.output_id -= 1
            if s.position > s_id:
                s.position -= 1
        result.delete(s_id)

    # for shader in result:
    #     echo(shader.output_named, " ", shader.output_id, " ", shader.inputs_id)

    # result.echo_position()

    var shuffled = true
    while shuffled:
        shuffled = false
        for shader in result.mitems:
            var modified = false
            if len(shader.inputs_id) == 0:
                continue
            var shift_high = 0
            for input in shader.inputs_id:
                if result[input].position > shift_high:
                    shift_high = result[input].position
            if shader.position < shift_high:
                shuffled = true
                modified = true
                var shift_low = shader.position
                # echo(shader.output_id, " ", shift_low, " ", shift_high)
                # echo(shader.position)
                for s2 in result.mitems:
                    if s2.position > shift_low and s2.position <= shift_high:
                        s2.position -= 1
                shader.position = shift_high
                # echo(shader.position)
            # if modified:
            #     result.echo_position()
        # result.echo_position()
    # result.echo_position()

proc sort_shaders*(tokenized: var seq[Tokenized]) =
    proc sort_by_position(t1, t2: Tokenized): int =
        cmp(t1.position, t2.position)

    tokenized.sort(sort_by_position)

# var serialized = serialize_shader_list(parse_all_config(files))
# serialized.echo_position()
# serialized.sort_shaders()

# for shader in serialized:
#     # echo(shader.shader_text)
#     echo(shader.position)
#     echo("end")
