import std/[locks, strutils]
import pugl
import make_ast, serialize, ast_to_shader, mesh, shader, run

var world: ptr Puglworld = puglnewworld(Puglprogram, 0'u32)

echo(puglstrerror(puglsetworldstring(world, PUGL_CLASS_NAME, "test")))

type SharedData* = object
    mutex *: Lock
    foo   *: float

puglsetworldhandle(world, alloc0(SharedData.sizeof))
# var shared_data: ptr SharedData = cast[ptr SharedData](puglgetworldhandle(world))

var view: ptr PuglView = puglnewview(world)

# const default_width: PuglSpan = 1920
# const default_height: PuglSpan = 1080

echo(puglstrerror(puglSetViewString(view, PUGL_WINDOW_TITLE, "My Window")))
echo(puglstrerror(puglSetSizeHint(view, PUGL_DEFAULT_SIZE, 1920, 1080)))
echo(puglstrerror(puglSetSizeHint(view, PUGL_MIN_SIZE, 640, 480)))
echo(puglstrerror(puglSetSizeHint(view, PUGL_MIN_ASPECT, 1, 1)))
echo(puglstrerror(puglSetSizeHint(view, PUGL_MAX_ASPECT, 16, 9)))

echo(puglstrerror(puglSetViewHint(view, PUGL_RESIZABLE, PUGL_TRUE)))
echo(puglstrerror(puglSetViewHint(view, PUGL_IGNORE_KEY_REPEAT, PUGL_TRUE)))

# echo(puglstrerror(puglsetparentwindow(view, native view handle)))

type ViewData* = object
    rd: RhabdomData

puglsethandle(view, alloc0(ViewData.sizeof))
# var view_data: ptr ViewData = cast[ptr ViewData](puglgethandle(view))
# var world2: ptr Puglworld = puglgetworld(view)

echo(puglstrerror(puglSetBackend(view, puglGlBackend())))

echo(puglstrerror(puglSetViewHint(view, PUGL_CONTEXT_VERSION_MAJOR, 3)))
echo(puglstrerror(puglSetViewHint(view, PUGL_CONTEXT_VERSION_MINOR, 3)))
echo(puglstrerror(puglSetViewHint(view, PUGL_CONTEXT_PROFILE, PUGL_OPENGL_CORE_PROFILE)))

proc onEvent(view: ptr PuglView, event: ptr PuglEvent): PuglStatus {.cdecl.} =
    var view_data: ptr ViewData = cast[ptr ViewData](puglgethandle(view))
    var world: ptr Puglworld = puglgetworld(view)
    case event.typefield:
        of Puglnothing:
            discard
        of Puglrealize:
            discard
        of Puglunrealize:
            discard
        of Puglconfigure:
            discard
            # echo("configure")
        of Puglupdate:
            discard
        of Puglexpose:
            frame(view_data.rd, event.configure.width, event.configure.height)
            # echo("error frame: " & $uint32(glGetError()))
        of Puglclose:
            quit()
        of Puglfocusin:
            echo("focus")
        of Puglfocusout:
            echo("unfocus")
        of Puglkeypress:
            echo("press" & chr(event.key.key))
        of Puglkeyrelease:
            echo("release" & chr(event.key.key))
        of Pugltext:
            discard
        of Puglpointerin:
            discard
        of Puglpointerout:
            discard
        of Puglbuttonpress:
            discard
        of Puglbuttonrelease:
            discard
        of Puglmotion:
            discard
        of Puglscroll:
            discard
        of Puglclient:
            discard
        of Pugltimer:
            discard
        of Puglloopenter:
            discard
        of Puglloopleave:
            discard
        of Pugldataoffer:
            discard
        of Pugldata:
            discard
    return Puglsuccess

echo(puglstrerror(puglseteventfunc(view, onEvent)))

var status: PuglStatus = puglrealize(view)
if status != Puglsuccess:
    echo("error realizing view")
    echo(puglstrerror(status))
    quit(1)

echo("glad load gl")
echo(puglstrerror(puglentercontext(view)))
assert gladLoadGL(puglGetProcAddress)
echo(cast[uint64](puglGetProcAddress("glGetString")))
echo(cast[cstring](cast[proc (name: GLenum): ptr GLubyte {.stdcall.}](puglGetProcAddress("glGetString"))(GL_VERSION)))

block:
    const shader_string: string = """
    mesh vertex_color;

    attrib vec3 position;
    attrib vec4 color;
    attrib vec4 uv;

    between vec4 color_interp;

    output vec4 frag_color;

    clear 0.0, 1.0, 0.0, 1.0;

    function void vertex()
    {
        gl_Position = vec4(position, 1.0);
        color_interp = color;
    }

    function void fragment()
    {
        //frag_color = vec4(1.0f, 0.5f, 0.2f, 1.0f);
        frag_color = vec4(color_interp.r, color_interp.g, color_interp.b, 1.0f);
    }
    """.dedent(4)
    var view_data: ptr ViewData = cast[ptr ViewData](puglgethandle(view))

    var ast_config    : seq[seq[Statement]]
    var ast_functions : seq[seq[Statement]]
    for s in [shader_string]:
        var ast = parse_to_ast(s)
        ast_config    &= ast[0]
        ast_functions &= ast[1]
        # echo(ast_config)

    var quad_vertices: array[36, float32] = [
        -0.5, -0.5, 0.0,   0.0, 0.0,   1.0, 0.0, 0.0, 1.0,
         0.5, -0.5, 0.0,   0.0, 1.0,   0.0, 1.0, 0.0, 1.0,
        -0.5,  0.5, 0.0,   1.0, 0.0,   0.0, 0.0, 1.0, 1.0,
         0.5,  0.5, 0.0,   1.0, 1.0,   0.5, 0.5, 0.0, 1.0,
    ]
    var quad_indices: array[6, uint32] = [0, 1, 2, 1, 2, 3]

    var tex_data: array[16, array[3, uint16]] = [
        [65535, 0, 0], [32767, 32767, 0], [0, 65535, 0], [0, 32767, 32767],
        [32767, 32767, 0], [0, 65535, 0], [0, 32767, 32767], [0, 0, 65535],
        [0, 65535, 0], [0, 32767, 32767],[65535, 0, 0], [32767, 32767, 0],
        [0, 32767, 32767], [65535, 0, 0], [32767, 32767, 0], [0, 65535, 0],
    ]

    view_data.rd.meshes.register_mesh("vertex_color",
        MeshData(
            num_vertices : 4,
            num_indices  : 6,
            buffers      : @[
                MeshBuffer(
                    data       : cast[ptr UncheckedArray[byte]](addr quad_vertices),
                    usage      : buStaticDraw,
                    attributes : @[
                        MeshAttr(
                            name      : "position",
                            number    : 3,
                            var_type  : matF32,
                            normalize : false,
                            location  : 0,
                        ),
                        MeshAttr(
                            name      : "uv",
                            number    : 2,
                            var_type  : matF32,
                            normalize : false,
                            location  : 1,
                        ),
                        MeshAttr(
                            name      : "color",
                            number    : 4,
                            var_type  : matF32,
                            normalize : false,
                            location  : 2,
                        )
                    ],
                    interlaced : true,
                )
            ],
            indices      : cast[ptr UncheckedArray[uint32]](addr quad_indices),
            index_usage  : buStaticDraw,
            mesh_type    : mkTriangles,
        )
    )

    for mesh in viewdata.rd.meshes.meshes.mitems():
        mesh_setup(mesh)
        # echo("error mesh: " & $uint32(glGetError()))
        discard glGetError()

    view_data.rd.shaders = view_data.rd.meshes.make_shaders(ast_config, ast_functions)

    for shader in viewdata.rd.shaders.mitems():
        shader_setup(shader)
        # echo("error shader: " & $uint32(glGetError()))
        discard glGetError()

    # echo(view_data.rd.shaders[0].text_vertex)
    # echo(view_data.rd.shaders[0].text_fragment)
    # # echo(len(view_data.rd.shaders))
    # # echo(view_data.rd.shaders[0])
    # echo(view_data.rd.shaders[0].log_program)
    # echo(view_data.rd.shaders[0].log_vertex)
    # echo(view_data.rd.shaders[0].log_fragment)
    # # echo(view_data.rd.meshes.meshes[0][])

echo(puglstrerror(puglleavecontext(view)))

# Puglshowpassive Puglshowraise Puglshowforceraise
echo(puglstrerror(puglshow(view, Puglshowforceraise)))

while true:
    discard puglUpdate(world, -1.0)
