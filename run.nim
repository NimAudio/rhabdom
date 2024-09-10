import std/[tables, strutils]
import pugl
import resource, shader, make_ast, serialize, ast_to_shader


var shader_string: string = """
mesh vertex_color;

attrib vec3 position;
attrib vec4 color;

between vec4 color_interp;

output vec4 frag_color;

function void vertex()
{
    gl_Position = vec4(position, 1.0);
    color_interp = color;
}

function void fragment()
{
    frag_color = vec4(color_interp.r, color_interp.g, color_interp.b, 1.0f); //vec4(1.0f, 0.5f, 0.2f, 1.0f);
}
"""

type RhabdomData* = object
    meshes  *: RhabdomMeshes
    shaders *: seq[Shader]

proc frame*(rd: RhabdomData, view_x, view_y: uint16) =
    for i in 0 ..< len(rd.shaders):
        #TODO implement enables/disables
        shader_frame(rd.shaders[i], view_x, view_y)
        mesh_frame(rd.meshes.meshes[rd.meshes.mesh_ordering[i]])

