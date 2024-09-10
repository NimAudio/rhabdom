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

    BufferUsage* {. size:sizeof(GLenum) .} = enum
        buStreamDraw  = GL_STREAM_DRAW,
        buStreamRead  = GL_STREAM_READ,
        buStreamCopy  = GL_STREAM_COPY,
        buStaticDraw  = GL_STATIC_DRAW,
        buStaticRead  = GL_STATIC_READ,
        buStaticCopy  = GL_STATIC_COPY,
        buDynamicDraw = GL_DYNAMIC_DRAW,
        buDynamicRead = GL_DYNAMIC_READ,
        buDynamicCopy = GL_DYNAMIC_COPY,

    MeshType* {. size:sizeof(GLenum) .} = enum
        mtPoints    = GL_POINTS,
        mtLines     = GL_LINES,
        mtLineLoop  = GL_LINE_LOOP,
        mtLineStrip = GL_LINE_STRIP,
        mtTriangles = GL_TRIANGLES,
        mtTriStrip  = GL_TRIANGLE_STRIP,
        mtTriFan    = GL_TRIANGLE_FAN,

    MeshAttr* = object
        name      *: string # must be unique and match name in shader
        number    *: range[1..4] = 3  # vec size
        var_type  *: MeshAttrType = matF32
        normalize *: bool = false
        location  *: uint32

    MeshBuffer* = object
        vbo_id        *: uint32
        data          *: ptr UncheckedArray[byte] # use attributes to calculate the size of one vertex, then multiplied by the number of vertices
        usage         *: BufferUsage
        attributes    *: seq[MeshAttr]
        interlaced    *: bool = true
        update_cb     *: proc (globals: pointer, data: ptr UncheckedArray[byte]): int = nil # can return new update frequency
        update_frames *: int # 0 does not run update_cb, 1 is every frame, 2 is every other frame

    MeshData* = object
        num_vertices *: int
        num_indices  *: int
        ibo_id       *: uint32
        vao_id       *: uint32
        buffers      *: seq[MeshBuffer]
        indices      *: ptr UncheckedArray[uint32] # indices probably always need to be uint32, im not sure if there's a 64 bit int type
        index_usage  *: BufferUsage
        mesh_type    *: MeshType

    RhabdomMeshes* = object
        meshes        *: seq[MeshData]      # set of all setup meshes
        mesh_ordering *: seq[int]           # for each pass, which mesh to use
        mesh_str_map  *: Table[string, int] # given a name, which mesh is it

proc byte_size*(mat: MeshAttrType): int =
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

    glGenBuffers(1, addr md.ibo_id)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, md.ibo_id)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, GLsizeiptr(md.num_indices * uint32.sizeof), addr md.indices, GLenum(md.index_usage))

    for buf in md.buffers:
        glGenBuffers(1, addr buf.vbo_id)
        glBindBuffer(GL_ARRAY_BUFFER, buf.vbo_id)
        var vert_size = 0
        for attr in buf.attributes:
            vert_size += attr.number * byte_size(attr.var_type)
        glBufferData(GL_ARRAY_BUFFER, GLsizeiptr(vert_size * md.num_vertices), buf.data, GLenum(buf.usage))

        if buf.interlaced:
            var attr_byte_pos = 0
            for attr in buf.attributes:
                glVertexAttribPointer(
                    GLuint(locations[attr.name]), # id/location
                    GLint(attr.number), # number of components
                    GLenum(attr.var_type), # type of attr
                    GLboolean(attr.normalize),
                    GLsizei(vert_size), # stride of one attr each
                    cast[pointer](attr_byte_pos) # offset based on total size of previous attrs
                )
                attr_byte_pos += attr.number * byte_size(attr.var_type) # size of one vertex worth of the attr
                glEnableVertexAttribArray(GLuint(locations[attr.name]))
        else:
            var attr_byte_pos = 0
            for attr in buf.attributes:
                glVertexAttribPointer(
                    GLuint(locations[attr.name]), # id/location
                    GLint(attr.number), # number of components
                    GLenum(attr.var_type), # type of attr
                    GLboolean(attr.normalize),
                    GLsizei(attr.number * byte_size(attr.var_type)), # stride of one attr
                    cast[pointer](attr_byte_pos) # offset based on total size of all verts worth of previous attrs
                )
                attr_byte_pos += attr.number * byte_size(attr.var_type) * md.num_vertices # size of all vertices worth of the attr
                glEnableVertexAttribArray(GLuint(locations[attr.name]))

    glBindBuffer(GL_ARRAY_BUFFER, 0)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0)
    glBindVertexArray(0)

proc mesh_frame*(md: MeshData) =
    # add blend funcs
    # add general glenable/disable system
    glBindVertexArray(md.vao_id)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, md.ibo_id)
    glDrawElements(GLenum(md.mesh_type), GLsizei(md.num_indices), GL_TYPE_UNSIGNED_INT, nil);

proc register_mesh*(rm: var RhabdomMeshes, name: string, md: MeshData) =
    rm.mesh_str_map[name] = len(rm.meshes)
    rm.meshes &= md


proc tex_setup*() =
    discard
proc tex_frame*() =
    discard

proc fb_setup*() =
    discard
proc fb_frame*() =
    discard
