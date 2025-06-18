/// The Official KTX library not being competable                       - Check
/// The Alternative TinyKTX library not usable due to vfile specific    - Check
/// The Zex library doesn't include ktx and lacks documentation         - Check
///
/// Welp, Time to get our hands dirty because we need to port the infamous
/// sb7ktx in-house library. I won't able to fully understand the
/// library because it has a lot of magic numbers, since I don't have
/// much time to investigate all the stuff, I have to use this
/// dreadful and horrible last resort.
///
/// Please don't follow my path, as this is a bad practice, but
/// I simply have no choice unless I have a solution from one of
/// the three attempt. If I work on actual production code,
/// I would use other format instead, but this "framework"
/// is sadly critical for learning the superbible book.
const std = @import("std");
const gl = @import("gl");

// Merged the header into the source, thus the header struct.
const Header = struct {
    identifier: [12]u8 = undefined,
    endianness: u32 = 0,
    gltype: u32 = 0,
    gltypesize: u32 = 0,
    glformat: u32 = 0,
    glinternalformat: u32 = 0,
    glbaseinternalformat: u32 = 0,
    pixelwidth: u32 = 0,
    pixelheight: u32 = 0,
    pixeldepth: u32 = 0,
    arrayelements: u32 = 0,
    faces: u32 = 0,
    miplevels: u32 = 0,
    keypairbytes: u32 = 0,
};

// The mystery in the original sb7ktx has been resolved
// My zig version uses the char version of the magic number: 0xAB, 0x4B, 0x54, 0x58, 0x20, 0x31, 0x31, 0xBB, 0x0D, 0x0A, 0x1A, 0x0A
// and the translation are based on the following documentation: https://registry.khronos.org/KTX/specs/1.0/ktxspec.v1.html
// This string is used for checking the first few bytes of the file such that to ensure the file being a KTX format.
const id_target = [_]u8{ '«', 'K', 'T', 'X', ' ', '1', '1', '»', '\r', '\n', '\x1A', '\n' };

pub fn calculateStride(h: *const Header, width: u32, pad_in: ?u32) u32 {
    const pad = pad_in orelse 4;

    const channals: u32 = switch (h.glbaseinternalformat) {
        gl.RED => 1,
        gl.RG => 2,
        gl.RGB, gl.BGR => 3,
        gl.BGRA, gl.RGBA => 4,
        else => 0,
    };

    var stride: u32 = h.gltypesize * channals * width;
    stride = (stride + (pad - 1)) & ~(pad - 1);

    return stride;
}

pub fn calculateFaceSize(header: *Header) u32 {
    return calculateStride(header, header.pixelwidth, null) * header.pixelheight;
}

/// load a texture based on the file location and load that data
/// into the opengl; once finished, return the texture ID
pub fn load(allocator: std.mem.Allocator, filename: []const u8, tex: *gl.uint) !gl.uint {
    var file = try std.fs.cwd().openFile(filename, .{});
    defer file.close(); // who needs goto if we have defer

    var bf = std.io.bufferedReader(file.reader());
    const fp = bf.reader();

    var header = Header{ .identifier = std.mem.zeroes([12]u8) };

    // fetch the first n digit of
    for (0..header.identifier.len) |i| {
        header.identifier[i] = try fp.readByte();
    }

    if (!std.mem.eql(u8, &header.identifier, &id_target)) {
        return error.IdentityNotMatched;
    }

    // since ktx has supported both big and small endian,
    // it has a 32 bit number to check the endianness of the data
    // so that to extract correct header information.
    // However, zig has a convenient feature for readInt which
    // it has builtin endian swap to replace the original
    // swap16 and swap32 functions in the in-house sb7ktx framework
    // thus, as long as we have used the endianess indicator,
    // we can let zig to swap bytes if needed
    // const endianess = try fp.readInt(u32, .big);    // 0x01020304
    // const endianess = try fp.readInt(u32, .little); // 0x04030201
    const endianess_raw = try fp.readInt(u32, .little);
    const endianess = switch (endianess_raw) {
        0x04030201 => std.builtin.Endian.little,
        0x01020304 => std.builtin.Endian.big,
        else => {
            return error.IllegalHeaderEndianess; // replacement of "goto fail_header"
        },
    };

    // the original sb7ktx preserve the endianess indicator, but since it is not used except for
    // checking the endianess, unless saving a new KTX texture in the save function.
    // I will discard this value instead.
    header.gltype = try fp.readInt(u32, endianess);
    header.gltypesize = try fp.readInt(u32, endianess);
    header.glformat = try fp.readInt(u32, endianess);
    header.glinternalformat = try fp.readInt(u32, endianess);
    header.glbaseinternalformat = try fp.readInt(u32, endianess);
    header.pixelwidth = try fp.readInt(u32, endianess);
    header.pixelheight = try fp.readInt(u32, endianess);
    header.pixeldepth = try fp.readInt(u32, endianess);
    header.arrayelements = try fp.readInt(u32, endianess);
    header.faces = try fp.readInt(u32, endianess);
    header.miplevels = try fp.readInt(u32, endianess);
    header.keypairbytes = try fp.readInt(u32, endianess);

    // Not ideal to leave these here, but they are important for dubug purpose
    // since testing is not possible locally due to the use of gl library
    // std.debug.print("pixelHeight: {d}\n", .{header.pixelwidth});
    // std.debug.print("pixelHeight: {d}\n", .{header.pixelheight});
    // std.debug.print("pixelHeight: {d}\n", .{header.pixeldepth});
    // std.debug.print("pixelHeight: {d}\n", .{header.arrayelements});

    // determining the type of texture based on the width, height and depth of the texture.
    var target: gl.uint = gl.NONE;
    if (header.pixelheight == 0) {
        target = if (header.arrayelements == 0) gl.TEXTURE_1D else gl.TEXTURE_1D_ARRAY;
    } else if (header.pixeldepth == 0) {
        if (header.arrayelements == 0) {
            target = if (header.faces == 0) gl.TEXTURE_2D else gl.TEXTURE_CUBE_MAP;
        } else {
            target = if (header.faces == 0) gl.TEXTURE_2D_ARRAY else gl.TEXTURE_CUBE_MAP_ARRAY;
        }
    } else {
        target = gl.TEXTURE_3D;
    }

    if (target == gl.NONE or header.pixelwidth == 0 or (header.pixelheight == 0 and header.pixeldepth != 0)) {
        return error.IllegalHeaderTarget; // replacement of "goto fail_header"
    }

    // Just like many other GL example, create and bind a texture if necessary
    if (tex.* == 0) {
        gl.GenTextures(1, (tex)[0..1]);
    }

    gl.BindTexture(target, tex.*);

    // The original C++ code did something crazy, using ftell to get the current
    // pointer location and getting another pointer representing the end of the file.
    // The current pointer is not the actual starting point of the fetch because it needs
    // to be set an offset by header.keypairbytes.
    // Luckily, zig file reader has enough functionality to have a work around, thus:
    var arena = std.heap.ArenaAllocator.init(allocator);
    defer arena.deinit();

    // with an aid of an arena allocator, we don't need all the ftell, fseek and memset madness
    // because we now have two overkill functions :
    //
    // - fp.skipBytes(num_bytes: u64, comptime options: SkipBytesOptions)
    // - fp.readAllAlloc(allocator: Allocator, max_size: usize)

    try fp.skipBytes(@intCast(header.keypairbytes), .{});
    const data = try fp.readAllAlloc(arena.allocator(), @intCast(try file.getEndPos()));

    header.miplevels = if (header.miplevels == 0) 1 else header.miplevels;

    switch (target) {
        gl.TEXTURE_1D => {
            process1DTexture(&header, data);
        },
        gl.TEXTURE_2D => {
            process2DTexture(&header, data);
        },
        gl.TEXTURE_3D => {
            process3DTexture(&header, data);
        },
        gl.TEXTURE_1D_ARRAY => {
            process1DArrayTexture(&header, data);
        },
        gl.TEXTURE_2D_ARRAY => {
            process2DArrayTexture(&header, data);
        },
        gl.TEXTURE_CUBE_MAP => {
            processCubeMapTexture(&header, data);
        },
        gl.TEXTURE_CUBE_MAP_ARRAY => {
            processCubeMapArrayTexture(&header, data);
        },
        else => {
            return error.IllegalTextureTarget;
        },
    }

    return tex.*;
}

fn process1DTexture(header: *Header, data: []u8) void {
    gl.TextureStorage1D(
        gl.TEXTURE_1D,
        @intCast(header.miplevels),
        @intCast(header.glinternalformat),
        @intCast(header.pixelwidth),
    );
    gl.TexSubImage1D(
        gl.TEXTURE_1D,
        0,
        0,
        @intCast(header.pixelwidth),
        header.glformat,
        header.gltype,
        @ptrCast(data.ptr),
    );
}

fn process2DTexture(header: *Header, data: []u8) void {
    if (header.gltype == gl.NONE) {
        // I have no idea about this magic number which is completely made up from the original C++ code
        const image_size: gl.sizei = 420 * (380 >> 1);

        gl.CompressedTexImage2D(
            gl.TEXTURE_2D,
            0,
            @intCast(header.glinternalformat),
            @intCast(header.pixelwidth),
            @intCast(header.pixelheight),
            0,
            image_size,
            @ptrCast(data.ptr),
        );
    } else {
        gl.TexStorage2D(
            gl.TEXTURE_2D,
            @intCast(header.miplevels),
            @intCast(header.glinternalformat),
            @intCast(header.pixelwidth),
            @intCast(header.pixelheight),
        );

        gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1);
        var i: u32 = 0;

        var height = header.pixelheight;
        var width = header.pixelwidth;

        // Since the original C++ requires to calculate the pointer location
        // and directly putting the raw pointer into the TexSubImage2D function,
        // I have to use a C pointer instead.
        var ptr = @as([*c]u8, @ptrCast(data.ptr));

        while (i < header.miplevels) : (i += 1) {
            gl.TexSubImage2D(
                gl.TEXTURE_2D,
                @intCast(i),
                0,
                0,
                @intCast(header.pixelwidth),
                @intCast(header.pixelheight),
                @intCast(header.glformat),
                @intCast(header.gltype),
                ptr,
            );
            // I have no idea what did the original library does in this part,
            // so in order to make things work, I have to copy the logic directly
            ptr += height * calculateStride(header, width, 1);
            height = if (height >> 1 != 0) height >> 1 else 1;
            width = if (width >> 1 != 0) width >> 1 else 1;
        }
    }
}

fn process3DTexture(header: *Header, data: []u8) void {
    gl.TexStorage3D(
        gl.TEXTURE_3D,
        @intCast(header.miplevels),
        @intCast(header.glinternalformat),
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.pixeldepth),
    );
    gl.TexSubImage3D(
        gl.TEXTURE_3D,
        0,
        0,
        0,
        0,
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.pixeldepth),
        @intCast(header.glformat),
        @intCast(header.gltype),
        @ptrCast(data.ptr),
    );
}

fn process1DArrayTexture(header: *Header, data: []u8) void {
    // by the code example, seems like an array of 1D texture is classified as 2D.
    // Just like people claiming one dimensional space with time is 2D.
    gl.TexStorage2D(
        gl.TEXTURE_1D_ARRAY,
        @intCast(header.miplevels),
        @intCast(header.glinternalformat),
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
    );

    gl.TexSubImage2D(
        gl.TEXTURE_1D_ARRAY,
        0,
        0,
        0,
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.glformat),
        @intCast(header.gltype),
        @ptrCast(data.ptr),
    );
}

fn process2DArrayTexture(header: *Header, data: []u8) void {
    gl.TexStorage3D(
        gl.TEXTURE_2D_ARRAY,
        @intCast(header.miplevels),
        @intCast(header.glinternalformat),
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.pixeldepth),
    );

    gl.TexSubImage3D(
        gl.TEXTURE_2D_ARRAY,
        0,
        0,
        0,
        0,
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.pixeldepth),
        @intCast(header.glformat),
        @intCast(header.gltype),
        @ptrCast(data.ptr),
    );
}

fn processCubeMapTexture(header: *Header, data: []u8) void {
    gl.TexStorage2D(
        gl.TEXTURE_CUBE_MAP,
        @intCast(header.miplevels),
        @intCast(header.glinternalformat),
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
    );

    const face_size = calculateFaceSize(header);
    var i: u32 = 0;

    while (i < header.faces) : (i += 1) {
        // this is more questionable and I am not sure if this actually works
        // unless it is actually triggered
        gl.TexSubImage2D(
            gl.TEXTURE_CUBE_MAP_POSITIVE_X + i,
            0,
            0,
            0,
            @intCast(header.pixelwidth),
            @intCast(header.pixelheight),
            @intCast(header.glformat),
            @intCast(header.gltype),
            @as([*c]u8, @ptrCast(data.ptr)) + face_size * i,
        );
    }
}

fn processCubeMapArrayTexture(header: *Header, data: []u8) void {
    gl.TexStorage3D(
        gl.TEXTURE_CUBE_MAP_ARRAY,
        @intCast(header.miplevels),
        @intCast(header.glformat),
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.pixelheight),
    );

    gl.TexSubImage3D(
        gl.TEXTURE_CUBE_MAP_ARRAY,
        0,
        0,
        0,
        0,
        @intCast(header.pixelwidth),
        @intCast(header.pixelheight),
        @intCast(header.arrayelements * header.faces),
        @intCast(header.glformat),
        @intCast(header.gltype),
        @ptrCast(data.ptr),
    );
}
