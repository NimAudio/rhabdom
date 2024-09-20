import std/[tables, strutils]
import pugl

# tkCubemapXP = GL_TEXTURE_CUBE_MAP_POSITIVE_X,
# tkCubemapXN = GL_TEXTURE_CUBE_MAP_NEGATIVE_X,
# tkCubemapYP = GL_TEXTURE_CUBE_MAP_POSITIVE_Y,
# tkCubemapYN = GL_TEXTURE_CUBE_MAP_NEGATIVE_Y,
# tkCubemapZP = GL_TEXTURE_CUBE_MAP_POSITIVE_Z,
# tkCubemapZN = GL_TEXTURE_CUBE_MAP_NEGATIVE_Z,
    # FilterMinify* {. size:sizeof(GLenum) .} = enum
    #     fminNearest = GL_NEAREST,
    #     fminLinear = GL_LINEAR,
    #     fminPixNearestMipNearest = GL_NEAREST_MIPMAP_NEAREST,
    #     fminPixLinearMipNearest = GL_LINEAR_MIPMAP_NEAREST,
    #     fminPixNearestMipLinear = GL_NEAREST_MIPMAP_LINEAR,
    #     fminPixLinearMipLinear = GL_LINEAR_MIPMAP_LINEAR,

    # FilterMagnify* {. size:sizeof(GLenum) .} = enum
    #     fmagNearest = GL_NEAREST,
    #     fmagLinear = GL_LINEAR,


type
    ChannelRemapValue* {. size:sizeof(GLenum) .} = enum
        crv0 = GLenum(GL_ZERO),
        crv1 = GLenum(GL_ONE),
        crvR = GL_RED,
        crvG = GL_GREEN,
        crvB = GL_BLUE,
        crvA = GL_ALPHA,

    ChannelRemap* = distinct array[4, ChannelRemapValue]

proc `[]`*(cr: var ChannelRemap, index: int): ChannelRemapValue =
    return array[4, ChannelRemapValue](cr)[index]
proc `[]=`*(cr: var ChannelRemap, index: int, val: ChannelRemapValue) =
    array[4, ChannelRemapValue](cr)[index] = val

converter channel_remap_from_string*(s: string): ChannelRemap =
    var chars = 4
    if len(s) < 3:
        return ChannelRemap([crvR, crvG, crvB, crvA])
    elif len(s) == 3:
        chars = 3
        result[3] = crv0
    for i in 0..<chars:
        var c = s[i].toLowerAscii()
        case c:
            of 'r', 'x':
                result[i] = crvR
            of 'g', 'y':
                result[i] = crvG
            of 'b', 'z':
                result[i] = crvB
            of 'a', 'w':
                result[i] = crvA
            of '1':
                result[i] = crv1
            of '0', '_':
                result[i] = crv0
            else:
                result[i] = crv0

type
    TextureKind* {. size:sizeof(GLenum) .} = enum
        tk1D           = GL_TEXTURE_1D,
        tk2D           = GL_TEXTURE_2D,
        tk3D           = GL_TEXTURE_3D,
        tkRectangle    = GL_TEXTURE_RECTANGLE,
        tkCubemap      = GL_TEXTURE_CUBE_MAP,
        tk1DArray      = GL_TEXTURE_1D_ARRAY,
        tk2DArray      = GL_TEXTURE_2D_ARRAY,
        tkCubemapArray = GL_TEXTURE_CUBE_MAP_ARRAY_ARB,
        tk2DMulti      = GL_TEXTURE_2D_MULTISAMPLE,
        tk2DMultiArray = GL_TEXTURE_2D_MULTISAMPLE_ARRAY,

proc tex_wrap_dims*(tk: TextureKind): int =
    case tk:
        of tkCubemap, tkCubemapArray:
            return 0
        of tk1D, tk1DArray:
            return 1
        of tk2D, tkRectangle, tk2DArray, tk2DMulti, tk2DMultiArray:
            return 2
        of tk3D:
            return 3

type
    TextureWrap* {. size:sizeof(GLenum) .} = enum
        twRepeat       = GL_REPEAT,
        twColor        = GL_CLAMP_TO_BORDER,
        twClamp        = GL_CLAMP_TO_EDGE,
        twMirrorRepeat = GL_MIRRORED_REPEAT,
        twMirrorOnce   = GL_MIRROR_CLAMP_TO_EDGE,

    PixelBitFormat* {. size:sizeof(GLenum) .} = enum
        pbfI8                 = GL_TYPE_BYTE,
        pbfU8                 = GL_TYPE_UNSIGNED_BYTE,
        pbfI16                = GL_TYPE_SHORT,
        pbfU16                = GL_TYPE_UNSIGNED_SHORT,
        pbfI32                = GL_TYPE_INT,
        pbfU32                = GL_TYPE_UNSIGNED_INT,
        pbfF32                = GL_TYPE_FLOAT,
        pbfF16                = GL_TYPE_HALF_FLOAT,
        pbfU8_332             = GL_UNSIGNED_BYTE_3_3_2,
        pbfU16_4444           = GL_UNSIGNED_SHORT_4_4_4_4,
        pbfU16_5551           = GL_UNSIGNED_SHORT_5_5_5_1,
        pbfU32_8888           = GL_UNSIGNED_INT_8_8_8_8,
        pbfU32_10_10_10_2     = GL_UNSIGNED_INT_10_10_10_2,
        pbfU8_233rev          = GL_UNSIGNED_BYTE_2_3_3_REV,
        pbfU16_565            = GL_UNSIGNED_SHORT_5_6_5,
        pbfU16_565rev         = GL_UNSIGNED_SHORT_5_6_5_REV,
        pbfU16_4444rev        = GL_UNSIGNED_SHORT_4_4_4_4_REV,
        pbfU16_1555rev        = GL_UNSIGNED_SHORT_1_5_5_5_REV,
        pbfU32_8888rev        = GL_UNSIGNED_INT_8_8_8_8_REV,
        pbfU32_2_10_10_10_rev = GL_UNSIGNED_INT_2_10_10_10_REV,

    PixelGPUFormat* {. size:sizeof(GLenum) .} = enum
        pgf_R3_G3_B2                    = GL_R3_G3_B2,                             # channel format: GL_RGB     bits: 3     3     2
        pgf_RGB_4                       = GL_RGB4,                                 # channel format: GL_RGB     bits: 4     4     4
        pgf_RGB_5                       = GL_RGB5,                                 # channel format: GL_RGB     bits: 5     5     5
        pgf_RGB_8                       = GL_RGB8,                                 # channel format: GL_RGB     bits: 8     8     8
        pgf_RGB_10                      = GL_RGB10,                                # channel format: GL_RGB     bits: 10    10    10
        pgf_RGB_12                      = GL_RGB12,                                # channel format: GL_RGB     bits: 12    12    12
        pgf_RGB_16                      = GL_RGB16,                                # channel format: GL_RGB     bits: 16    16    16
        pgf_RGBA_2                      = GL_RGBA2,                                # channel format: GL_RGB     bits: 2     2     2     2
        pgf_RGBA_4                      = GL_RGBA4,                                # channel format: GL_RGB     bits: 4     4     4     4
        pgf_RGB_5_A1                    = GL_RGB5_A1,                              # channel format: GL_RGBA    bits: 5     5     5     1
        pgf_RGBA_8                      = GL_RGBA8,                                # channel format: GL_RGBA    bits: 8     8     8     8
        pgf_RGB_10_A_I2                 = GL_RGB10_A2,                             # channel format: GL_RGBA    bits: 10    10    10    2
        pgf_RGBA_12                     = GL_RGBA12,                               # channel format: GL_RGBA    bits: 12    12    12    12
        pgf_RGBA_16                     = GL_RGBA16,                               # channel format: GL_RGBA    bits: 16    16    16    16
        pgf_Compressed_R                = GL_COMPRESSED_RED,                       # channel format: GL_RED   
        pgf_Compressed_RG               = GL_COMPRESSED_RG,                        # channel format: GL_RG   
        pgf_R8                          = GL_R8,                                   # channel format: GL_RED     bits: 8
        pgf_R16                         = GL_R16,                                  # channel format: GL_RED     bits: 16
        pgf_RG8                         = GL_RG8,                                  # channel format: GL_RG      bits: 8     8
        pgf_RG16                        = GL_RG16,                                 # channel format: GL_RG      bits: 16    16
        pgf_R_F16                       = GL_R16F,                                 # channel format: GL_RED     bits: f16
        pgf_R_F32                       = GL_R32F,                                 # channel format: GL_RED     bits: f32
        pgf_RG_F16                      = GL_RG16F,                                # channel format: GL_RG      bits: f16   f16
        pgf_RG_F32                      = GL_RG32F,                                # channel format: GL_RG      bits: f32   f32
        pgf_R_I8                        = GL_R8I,                                  # channel format: GL_RED     bits: i8
        pgf_R_U8                        = GL_R8UI,                                 # channel format: GL_RED     bits: ui8
        pgf_R_I16                       = GL_R16I,                                 # channel format: GL_RED     bits: i16
        pgf_R_U16                       = GL_R16UI,                                # channel format: GL_RED     bits: ui16
        pgf_R_I32                       = GL_R32I,                                 # channel format: GL_RED     bits: i32
        pgf_R_U32                       = GL_R32UI,                                # channel format: GL_RED     bits: ui32
        pgf_RG_I8                       = GL_RG8I,                                 # channel format: GL_RG      bits: i8    i8
        pgf_RG_U8                       = GL_RG8UI,                                # channel format: GL_RG      bits: ui8   ui8
        pgf_RG_I16                      = GL_RG16I,                                # channel format: GL_RG      bits: i16   i16
        pgf_RG_U16                      = GL_RG16UI,                               # channel format: GL_RG      bits: ui16  ui16
        pgf_RG_I32                      = GL_RG32I,                                # channel format: GL_RG      bits: i32   i32
        pgf_RG_U32                      = GL_RG32UI,                               # channel format: GL_RG      bits: ui32  ui32
        pgf_Compressed_RGB_DXT1         = GL_COMPRESSED_RGB_S3TC_DXT1_EXT,         # channel format: GL_RGB   
        pgf_Compressed_RGBA_DXT1        = GL_COMPRESSED_RGBA_S3TC_DXT1_EXT,        # channel format: GL_RGBA   
        pgf_Compressed_RGBA_DXT3        = GL_COMPRESSED_RGBA_S3TC_DXT3_EXT,        # channel format: GL_RGBA   
        pgf_Compressed_RGBA_DXT5        = GL_COMPRESSED_RGBA_S3TC_DXT5_EXT,        # channel format: GL_RGBA   
        pgf_Compressed_RGB              = GL_COMPRESSED_RGB,                       # channel format: GL_RGB   
        pgf_Compressed_RGBA             = GL_COMPRESSED_RGBA,                      # channel format: GL_RGBA   
        pgf_RGBA_F32                    = GL_RGBA32F,                              # channel format: GL_RGBA    bits: f32   f32   f32 f32
        pgf_RGB_F32                     = GL_RGB32F,                               # channel format: GL_RGB     bits: f32   f32   f32
        pgf_RGBA_F16                    = GL_RGBA16F,                              # channel format: GL_RGBA    bits: f16   f16   f16   f16
        pgf_RGB_F16                     = GL_RGB16F,                               # channel format: GL_RGB     bits: f16   f16   f16
        pgf_RGB_F11_F11_F10             = GL_R11F_G11F_B10F,                       # channel format: GL_RGB     bits: f11   f11   f10
        pgf_RGB9_E5                     = GL_RGB9_E5,                              # channel format: GL_RGB     bits: 9     9     9
        pgf_sRGB_8                      = GL_SRGB8,                                # channel format: GL_RGB     bits: 8     8     8
        pgf_sRGB_8_A8                   = GL_SRGB8_ALPHA8,                         # channel format: GL_RGBA    bits: 8     8     8     8
        pgf_Compressed_sRGB             = GL_COMPRESSED_SRGB,                      # channel format: GL_RGB   
        pgf_Compressed_sRGBA            = GL_COMPRESSED_SRGB_ALPHA,                # channel format: GL_RGBA   
        pgf_Compressed_sLuma            = GL_COMPRESSED_SLUMINANCE_EXT,            # channel format: GL_R   
        pgf_Compressed_sLuma_A          = GL_COMPRESSED_SLUMINANCE_ALPHA_EXT,      # channel format: GL_RA   
        pgf_Compressed_sRGB_DXT1        = GL_COMPRESSED_SRGB_S3TC_DXT1_EXT,        # channel format: GL_RGB   
        pgf_Compressed_sRGBA_DXT1       = GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT1_EXT,  # channel format: GL_RGBA   
        pgf_Compressed_sRGBA_DXT3       = GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT3_EXT,  # channel format: GL_RGBA   
        pgf_Compressed_sRGBA_DXT5       = GL_COMPRESSED_SRGB_ALPHA_S3TC_DXT5_EXT,  # channel format: GL_RGBA   
        pgf_RGBA_U32                    = GL_RGBA32UI,                             # channel format: GL_RGBA    bits: ui32  ui32  ui32  ui32
        pgf_RGB_U32                     = GL_RGB32UI,                              # channel format: GL_RGB     bits: ui32  ui32  ui32
        pgf_RGBA_U16                    = GL_RGBA16UI,                             # channel format: GL_RGBA    bits: ui16  ui16  ui16  ui16
        pgf_RGB_U16                     = GL_RGB16UI,                              # channel format: GL_RGB     bits: ui16  ui16  ui16
        pgf_RGBA_U8                     = GL_RGBA8UI,                              # channel format: GL_RGBA    bits: ui8   ui8   ui8   ui8
        pgf_RGB_U8                      = GL_RGB8UI,                               # channel format: GL_RGB     bits: ui8   ui8   ui8
        pgf_RGBA_I32                    = GL_RGBA32I,                              # channel format: GL_RGBA    bits: i32   i32   i32   i32
        pgf_RGB_I32                     = GL_RGB32I,                               # channel format: GL_RGB     bits: i32   i32   i32
        pgf_RGBA_I16                    = GL_RGBA16I,                              # channel format: GL_RGBA    bits: i16   i16   i16   i16
        pgf_RGB_I16                     = GL_RGB16I,                               # channel format: GL_RGB     bits: i16   i16   i16
        pgf_RGBA_I8                     = GL_RGBA8I,                               # channel format: GL_RGBA    bits: i8    i8    i8    i8
        pgf_RGB_I8                      = GL_RGB8I,                                # channel format: GL_RGB     bits: i8    i8    i8
        pgf_Compressed_R_RGTC1          = GL_COMPRESSED_RED_RGTC1,                 # channel format: GL_RED   
        pgf_Compressed_R_RGTC1_signed   = GL_COMPRESSED_SIGNED_RED_RGTC1,          # channel format: GL_RED   
        pgf_Compressed_RG_RGCT2         = GL_COMPRESSED_RG_RGTC2,                  # channel format: GL_RG   
        pgf_Compressed_RG_RGCT2_signed  = GL_COMPRESSED_SIGNED_RG_RGTC2,           # channel format: GL_RG   
        pgf_R8_snorm                    = GL_R8_SNORM,                             # channel format: GL_RED     bits: s8
        pgf_RG8_snorm                   = GL_RG8_SNORM,                            # channel format: GL_RG      bits: s8    s8
        pgf_RGB_8_snorm                 = GL_RGB8_SNORM,                           # channel format: GL_RGB     bits: s8    s8    s8
        pgf_RGBA_8_snorm                = GL_RGBA8_SNORM,                          # channel format: GL_RGBA    bits: s8    s8    s8    s8
        pgf_R16_snorm                   = GL_R16_SNORM,                            # channel format: GL_RED     bits: s16
        pgf_RG16_snorm                  = GL_RG16_SNORM,                           # channel format: GL_RG      bits: s16   s16
        pgf_RGB_16_snorm                = GL_RGB16_SNORM,                          # channel format: GL_RGB     bits: 16    16    16
        pgf_RGB_10_A_U2                 = GL_RGB10_A2UI,                           # channel format: GL_RGBA    bits: ui10  ui10  ui10  ui2

    PixelChannelFormat* {. size:sizeof(GLenum) .} = enum
        pcfS         = GL_STENCIL_INDEX,
        pcfD         = GL_DEPTH_COMPONENT,
        pcfR         = GL_RED,
        pcfG         = GL_GREEN,
        pcfB         = GL_BLUE,
        pcfRGB       = GL_RGB,
        pcfRGBA      = GL_RGBA,
        pcfBGR       = GL_BGR,
        pcfBGRA      = GL_BGRA,
        pcfRG        = GL_RG,
        pcfRG_int    = GL_RG_INTEGER,
        pcfDS        = GL_DEPTH_STENCIL,
        pcfR_int     = GL_RED_INTEGER,
        pcfG_int     = GL_GREEN_INTEGER,
        pcfB_int     = GL_BLUE_INTEGER,
        pcfRGB_int   = GL_RGB_INTEGER,
        pcfRGBA_int  = GL_RGBA_INTEGER,
        pcfBGR_int   = GL_BGR_INTEGER,
        pcfBGRA_int  = GL_BGRA_INTEGER,

proc channel_format*(format: PixelGPUFormat, flip = false, integer: bool = false, select: char = 'R'): PixelChannelFormat =
    case format:
        of pgf_Compressed_R, pgf_R8, pgf_R16, pgf_R_F16, pgf_R_F32, pgf_R_I8, pgf_R_U8, pgf_R_I16, pgf_R_U16, pgf_R_I32, pgf_R_U32, pgf_Compressed_sLuma, pgf_Compressed_R_RGTC1, pgf_Compressed_R_RGTC1_signed, pgf_R8_snorm, pgf_R16_snorm:
            return if select.toUpperAscii() == 'R':
                    if integer:
                        pcfR_int
                    else:
                        pcfR
                elif select.toUpperAscii() == 'G':
                    if integer:
                        pcfG_int
                    else:
                        pcfG
                elif select.toUpperAscii() == 'B':
                    if integer:
                        pcfB_int
                    else:
                        pcfB
                elif select.toUpperAscii() == 'D':
                    pcfD
                elif select.toUpperAscii() == 'S':
                    pcfS
                else:
                    pcfR
        of pgf_Compressed_RG, pgf_RG8, pgf_RG16, pgf_RG_F16, pgf_RG_F32, pgf_RG_I8, pgf_RG_U8, pgf_RG_I16, pgf_RG_U16, pgf_RG_I32, pgf_RG_U32, pgf_Compressed_sLuma_A, pgf_Compressed_RG_RGCT2, pgf_Compressed_RG_RGCT2_signed, pgf_RG8_snorm, pgf_RG16_snorm:
            return if select.toUpperAscii() in ['D', 'S']:
                    pcfDS
                else:
                    if integer:
                        pcfRG_int
                    else:
                        pcfRG
        of pgf_R3_G3_B2, pgf_RGB_4, pgf_RGB_5, pgf_RGB_8, pgf_RGB_10, pgf_RGB_12, pgf_RGB_16, pgf_RGBA_2, pgf_RGBA_4, pgf_Compressed_RGB_DXT1, pgf_Compressed_RGB, pgf_RGB_F32, pgf_RGB_F16, pgf_RGB_F11_F11_F10, pgf_RGB9_E5, pgf_sRGB_8, pgf_Compressed_sRGB, pgf_Compressed_sRGB_DXT1, pgf_RGB_U32, pgf_RGB_U16, pgf_RGB_U8, pgf_RGB_I32, pgf_RGB_I16, pgf_RGB_I8, pgf_RGB_8_snorm, pgf_RGB_16_snorm:
            return if flip:
                    if integer:
                        pcfRGB_int
                    else:
                        pcfRGB
                else:
                    if integer:
                        pcfBGR_int
                    else:
                        pcfBGR
        of pgf_RGB_5_A1, pgf_RGBA_8, pgf_RGB_10_A_I2, pgf_RGBA_12, pgf_RGBA_16, pgf_Compressed_RGBA_DXT1, pgf_Compressed_RGBA_DXT3, pgf_Compressed_RGBA_DXT5, pgf_Compressed_RGBA, pgf_RGBA_F32, pgf_RGBA_F16, pgf_sRGB_8_A8, pgf_Compressed_sRGBA, pgf_Compressed_sRGBA_DXT1, pgf_Compressed_sRGBA_DXT3, pgf_Compressed_sRGBA_DXT5, pgf_RGBA_U32, pgf_RGBA_U16, pgf_RGBA_U8, pgf_RGBA_I32, pgf_RGBA_I16, pgf_RGBA_I8, pgf_RGBA_8_snorm, pgf_RGB_10_A_U2:
            return if flip:
                    if integer:
                        pcfRGBA_int
                    else:
                        pcfRGBA
                else:
                    if integer:
                        pcfBGRA_int
                    else:
                        pcfBGRA

type
    DataAlignment* {. size:sizeof(uint32) .} = enum
        da1 = 1,
        da2 = 2,
        da4 = 4,
        da8 = 8,

    TextureData* = object
        data          *: ptr UncheckedArray[byte]
        update_cb     *: proc (globals: pointer, data: ptr UncheckedArray[byte]): int = nil # can return new update frequency
        update_frames *: int # 0 does not run update_cb, 1 is every frame, 2 is every other frame
        data_bit_format *: PixelBitFormat
        channel_format  *: PixelChannelFormat
        # writing image to gpu
        gl_unpack_swap_bytes   *: bool = false
        gl_unpack_LSB_first    *: bool = false
        gl_unpack_row_len      *: uint32
        gl_unpack_image_height *: uint32
        gl_unpack_skip_rows    *: uint32
        gl_unpack_skip_pixels  *: uint32
        gl_unpack_skip_images  *: uint32
        gl_unpack_alignment    *: DataAlignment = da4
        # read image from gpu
        # gl_pack_swap_bytes   *: bool = false
        # gl_pack_LSB_first    *: bool = false
        # gl_pack_row_len      *: uint32
        # gl_pack_image_height *: uint32
        # gl_pack_skip_rows    *: uint32
        # gl_pack_skip_pixels  *: uint32
        # gl_pack_skip_images  *: uint32
        # gl_pack_alignment    *: DataAlignment = da4

    Texture* = ref object
        tex_id     *: uint32
        width      *: uint32
        height     *: uint32
        remap      *: ChannelRemap = "rgba"
        wrap_x     *: TextureWrap = twRepeat
        wrap_y     *: TextureWrap = twRepeat
        wrap_z     *: TextureWrap = twRepeat
        kind       *: TextureKind = tk2D
        gpu_format *: PixelGPUFormat
        filter_max_linear *: bool = true
        filter_min_linear *: bool = true
        filter_mipmap     *: bool = true
        filter_mip_lin    *: bool = true
        data              *: TextureData

    RhabdomTextures* = object
        textures             *: seq[Texture]
        tex_str_map          *: Table[string, int]
        shader_tex_bindings  *: seq[Table[string, uint8]] # each shader index in order
        shader_stage_changes *: seq[seq[(uint32, uint8)]] # for each shader pass, what needs to be bound to what

proc tex_setup*(tex: var Texture) =
    glGenTextures(1, addr tex.tex_id)
    glBindTexture(GLenum(tex.kind), tex.tex_id)
    var wrap_dims = tex_wrap_dims(tex.kind)
    if wrap_dims > 0:
        glTexParameteri(GLenum(tex.kind), GL_TEXTURE_WRAP_S, GLint(tex.wrap_x))
    elif wrap_dims > 1:
        glTexParameteri(GLenum(tex.kind), GL_TEXTURE_WRAP_T, GLint(tex.wrap_y))
    elif wrap_dims > 2:
        glTexParameteri(GLenum(tex.kind), GL_TEXTURE_WRAP_R, GLint(tex.wrap_z))
    glTexParameteri(GLenum(tex.kind), GL_TEXTURE_MAG_FILTER, GLint(if tex.filter_max_linear: GL_LINEAR else: GL_NEAREST))
    var min_filter =
        if tex.filter_mipmap:
            if tex.filter_min_linear:
                if tex.filter_mip_lin:
                    GL_LINEAR_MIPMAP_LINEAR
                else:
                    GL_LINEAR_MIPMAP_NEAREST
            else:
                if tex.filter_mip_lin:
                    GL_NEAREST_MIPMAP_LINEAR
                else:
                    GL_NEAREST_MIPMAP_NEAREST
        else:
            if tex.filter_min_linear:
                GL_LINEAR
            else:
                GL_NEAREST
    glTexParameteri(GLenum(tex.kind), GL_TEXTURE_MIN_FILTER, GLint(min_filter))
    if tex.data.data != nil:
        glTexImage2D(
            GLenum(tex.kind),
            GLint(0),
            GLint(tex.gpu_format),
            GLsizei(tex.width),
            GLsizei(tex.height),
            GLint(0),
            GLenum(tex.data.channel_format),
            GLenum(tex.data.data_bit_format),
            tex.data.data);
        if tex.filter_mipmap:
            glGenerateMipmap(GLenum(tex.kind));
    else:
        echo("texture data null pointer")
        quit(1)

proc bind_textures*(rt: var RhabdomTextures, name: string, pass: int, bind_slot: uint8) =
    rt.shader_tex_bindings[pass][name] = bind_slot

proc tex_frame*(tex: var Texture) =
    glBindTexture(GLenum(tex.kind), tex.tex_id);


proc fb_setup*() =
    discard
proc fb_frame*() =
    discard
