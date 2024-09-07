import pugl

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
        view_x *: uint16
        view_y *: uint16
        clear_color *: array[4, float32]

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

proc shader_frame*(sh: Shader) =
    glViewport(0, 0, GLsizei(sh.view_x), GLsizei(sh.view_y))
    glClearColor(sh.clear_color[0], sh.clear_color[1], sh.clear_color[2], sh.clear_color[3])
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT)
    glUseProgram(sh.id_program)
