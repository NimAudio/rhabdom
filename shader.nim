import pugl
import make_ast, serialize, ast_to_shader, resource
import std/[tables, strutils]

type
    Shader* = object
        text_vertex   *: string
        text_fragment *: string
        id_program  *: uint32
        id_vertex   *: uint32
        id_fragment *: uint32
        log_program  *: cstring
        log_vertex   *: cstring
        log_fragment *: cstring
        view_x     *: uint16
        view_y     *: uint16
        view_scale *: float
        clear_color *: array[4, float32]
        mesh_id *: string

proc shader_setup*(sh: var Shader) =
    # make vertex shader
    sh.id_vertex = glCreateShader(GL_VERTEX_SHADER)
    glShaderSource(GLuint(sh.id_vertex), GLsizei(1), allocCStringArray([sh.text_vertex]), nil)
    glCompileShader(sh.id_vertex)
    var success: int32
    glGetShaderiv(sh.id_vertex, GL_COMPILE_STATUS, addr success)
    if success == 0:
        glGetShaderInfoLog(sh.id_vertex, 512, nil, sh.log_vertex)
        # echo("vertex shader compilation failed")
        # echo(sh.log_vertex)

    # make fragment shader
    sh.id_fragment = glCreateShader(GL_FRAGMENT_SHADER)
    glShaderSource(GLuint(sh.id_fragment), GLsizei(1), allocCStringArray([sh.text_fragment]), nil)
    glCompileShader(sh.id_fragment)
    # var success: int32
    glGetShaderiv(sh.id_fragment, GL_COMPILE_STATUS, addr success)
    if success == 0:
        glGetShaderInfoLog(sh.id_fragment, 512, nil, sh.log_fragment)
        # echo("fragment shader compilation failed")
        # echo(sh.log_fragment)

    # make shader program
    sh.id_program = glCreateProgram()
    glAttachShader(sh.id_program, sh.id_vertex)
    glAttachShader(sh.id_program, sh.id_fragment)
    glLinkProgram(sh.id_program)
    glGetProgramiv(sh.id_program, GL_LINK_STATUS, addr success)
    if success == 0:
        glGetProgramInfoLog(sh.id_program, 512, nil, sh.log_program)
        # echo("shader program link failed")
        # echo(sh.log_program)
    # glUseProgram(sh.id_program)
    glDeleteShader(sh.id_vertex)
    glDeleteShader(sh.id_fragment)

proc shader_frame*(sh: Shader, view_x, view_y: uint16) =
    if sh.view_scale < 0:
        glViewport(0, 0, GLsizei(sh.view_x), GLsizei(sh.view_y))
    else:
        glViewport(0, 0, GLsizei(float(view_x) * sh.view_scale), GLsizei(float(view_y) * sh.view_scale))
    glClearColor(sh.clear_color[0], sh.clear_color[1], sh.clear_color[2], sh.clear_color[3])
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    glUseProgram(sh.id_program)

proc make_shaders*(
        meshes        : RhabdomMeshes,
        ast_config    : seq[seq[Statement]],
        ast_functions : seq[seq[Statement]],
        view_xy       : array[2, int] = [800, 600]
    ): seq[Shader] =
    if len(ast_config) == 1:
        var clear_color: array[4, float32]
        var view_x = view_xy[0]
        var view_y = view_xy[1]
        var view_scale: float
        for st in ast_config[0]:
            if st.kind == pkClearColor:
                clear_color = st.color
            elif st.kind == pkResScale:
                if len(st.var_type) > 0: # y, x
                    view_y = parseInt(st.var_type)
                    view_x = parseInt(st.name)
                    view_scale = -1.0
                else: # scale
                    view_scale = parseFloat(st.name)
                    # var scale = parseFloat(st.name)
                    # view_x = int(float(view_xy[0]) * scale)
                    # view_y = int(float(view_xy[1]) * scale)
        result &= Shader(
            text_vertex   : make_vertex_shader(  ast_config[0], ast_functions[0]),
            text_fragment : make_fragment_shader(ast_config[0], ast_functions[0]),
            view_x        : uint16(view_x),
            view_y        : uint16(view_y),
            view_scale    : view_scale,
            clear_color   : clear_color
        )
    # else:
    #     var serialized: seq[Tokenized] = serialize_shader_list(ast_config)