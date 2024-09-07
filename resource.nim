import std/tables

import pugl

type
    MeshAttrType* {. size:sizeof(GLenum) .} = enum
        matI8  = GL_TYPE_BYTE,
        matU8  = GL_TYPE_UNSIGNED_BYTE,
        matI16 = GL_TYPE_SHORT,
        matU16 = GL_TYPE_UNSIGNED_SHORT,
        matI32 = GL_TYPE_INT,
        matU32 = GL_TYPE_UNSIGNED_INT,
        matF32 = GL_TYPE_FLOAT,
        matF64 = GL_TYPE_DOUBLE,
        matF16 = GL_TYPE_HALF_FLOAT,

    MeshUsage* {. size:sizeof(GLenum) .} = enum
        muStreamDraw  = GL_STREAM_DRAW,
        muStreamRead  = GL_STREAM_READ,
        muStreamCopy  = GL_STREAM_COPY,
        muStaticDraw  = GL_STATIC_DRAW,
        muStaticRead  = GL_STATIC_READ,
        muStaticCopy  = GL_STATIC_COPY,
        muDynamicDraw = GL_DYNAMIC_DRAW,
        muDynamicRead = GL_DYNAMIC_READ,
        muDynamicCopy = GL_DYNAMIC_COPY,

    MeshType* {. size:sizeof(GLenum) .} = enum
        mtPoints    = GL_POINTS,
        mtLines     = GL_LINES,
        mtLineLoop  = GL_LINE_LOOP,
        mtLineStrip = GL_LINE_STRIP,
        mtTriangles = GL_TRIANGLES,
        mtTriStrip  = GL_TRIANGLE_STRIP,
        mtTriFan    = GL_TRIANGLE_FAN,

    MeshAttr* = object
        name      *: string
        number    *: range[1..4] = 3  # vec size
        var_type  *: MeshAttrType = matF32
        normalize *: bool = false

    MeshData* = object
        num_vertices *: int
        attributes   *: seq[MeshAttr]
        num_indices  *: int
        vbo_id       *: uint32
        ibo_id       *: uint32
        vao_id       *: uint32
        vertices     *: ptr UncheckedArray[byte] # use attributes to calculate the size of one vertex, then multiplied by the number of vertices
        indices      *: ptr UncheckedArray[uint32] # indices probably always need to be uint32, im not sure if there's a 64 bit int type
        usage        *: MeshUsage
        mesh_type    *: MeshType

proc byte_size*(mat: MeshAttrType): int32 =
    case mat:
        of matI8:
            result = 1
        of matU8:
            result = 1
        of matI16:
            result = 2
        of matU16:
            result = 2
        of matI32:
            result = 4
        of matU32:
            result = 4
        of matF32:
            result = 4
        of matF64:
            result = 8
        of matF16:
            result = 2

proc mesh_setup*(md: var MeshData, locations: Table[string, uint32]) =
    glGenVertexArrays(1, addr md.vao_id)
    glBindVertexArray(md.vao_id)

    glGenBuffers(1, addr md.vbo_id)
    glBindBuffer(GL_ARRAY_BUFFER, md.vbo_id)
    var vert_size: int32 = 0
    for attr in md.attributes:
        vert_size += int32(attr.number) * byte_size(attr.var_type)
    glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(vert_size * md.num_vertices), md.vertices, GLenum(md.usage))

    glGenBuffers(1, addr md.ibo_id)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, md.ibo_id)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, GLsizeiptr(md.num_indices * uint32.sizeof), addr md.indices, GLenum(md.usage))

    var attr_byte_pos: int32 = 0
    for attr in md.attributes:
        glVertexAttribPointer(
            GLuint(locations[attr.name]),
            GLint(attr.number),
            GLenum(attr.var_type),
            GLboolean(attr.normalize),
            GLsizei(vert_size),
            cast[pointer](attr_byte_pos)
        )
        attr_byte_pos += attr.number * byte_size(attr.var_type)
    # glVertexAttribPointer(0, 3, GL_TYPE_FLOAT, GL_FALSE, 7 * float32.sizeof, cast[pointer](0))
    # glVertexAttribPointer(1, 4, GL_TYPE_FLOAT, GL_FALSE, 7 * float32.sizeof, cast[pointer](3 * float32.sizeof))
    glEnableVertexAttribArray(0)
    glEnableVertexAttribArray(1)

    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
    glBindVertexArray(0)

proc mesh_frame*(md: MeshData) =
    # add blend funcs
    # add general glenable/disable system
    glBindVertexArray(md.vao_id)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, md.ibo_id)
    glDrawElements(GLenum(md.mesh_type), GLsizei(md.num_indices), GL_TYPE_UNSIGNED_INT, nil);


proc tex_setup*() =
    discard
proc tex_frame*() =
    discard

proc fb_setup*() =
    discard
proc fb_frame*() =
    discard
