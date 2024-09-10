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
    # for i in 0 ..< len(rd.shaders):
    #     #TODO implement enables/disables
    #     shader_frame(rd.shaders[i], view_x, view_y)
    #     mesh_frame(rd.meshes.meshes[rd.meshes.mesh_ordering[i]])
    # echo(view_x, " ", view_y)
    shader_frame(rd.shaders[0], view_x, view_y)
    mesh_frame(rd.meshes.meshes[0])

# var rd: RhabdomData

# var ast_config    : seq[seq[Statement]]
# var ast_functions : seq[seq[Statement]]
# for s in [shader_string]:
#     var ast = parse_to_ast(s)
#     ast_config    &= ast[0]
#     ast_functions &= ast[1]

# # shaders = make

# var quad_vertices: array[28, float32] = [
#     -0.5, -0.5, 0.0,   1.0, 0.0, 0.0, 1.0,
#     0.5, -0.5, 0.0,   0.0, 1.0, 0.0, 1.0,
#     -0.5,  0.5, 0.0,   0.0, 0.0, 1.0, 1.0,
#     0.5,  0.5, 0.0,   0.5, 0.5, 0.0, 1.0,
# ]
# var quad_indices: array[6, int] = [0, 1, 2, 1, 2, 3]

# rd.meshes.register_mesh("vertex_color",
#     MeshData(
#         num_vertices : 4,
#         num_indices  : 6,
#         buffers      : @[
#             MeshBuffer(
#                 data       : cast[ptr UncheckedArray[byte]](addr quad_vertices),
#                 usage      : buStaticDraw,
#                 attributes : @[
#                     MeshAttr(
#                         name      : "position",
#                         number    : 3,
#                         var_type  : matF32,
#                         normalize : false,
#                         location  : 0,
#                     ),
#                     MeshAttr(
#                         name      : "color",
#                         number    : 4,
#                         var_type  : matF32,
#                         normalize : false,
#                         location  : 1,
#                     )
#                 ],
#                 interlaced : true,
#             )
#         ],
#         indices      : cast[ptr UncheckedArray[uint32]](addr quad_indices),
#         index_usage  : buStaticDraw,
#         mesh_type    : mtTriangles,
#     )
# )

# rd.shaders = rd.meshes.make_shaders(ast_config, ast_functions)
