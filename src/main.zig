// These are the libraries used in the examples,
// you may find the respostories from build.zig.zon
const std = @import("std");
const zm = @import("zm");
const app = @import("sb7.zig");
const ktx = @import("sb7ktx.zig");
const shader = @import("shaders_tunnel.zig");

var program: app.gl.uint = undefined;
var vao: app.gl.uint = undefined;

var tex_wall: app.gl.uint = undefined;
var tex_ceiling: app.gl.uint = undefined;
var tex_floor: app.gl.uint = undefined;

// There are too few variables, used individual var instead of a struct
var uni_mvp: app.gl.int = undefined;
var uni_offset: app.gl.int = undefined;

pub fn main() !void {
    // Many people seem to hate the dynamic loading part of the program.
    // I also hate it too, but I don't seem to find a good solution (yet)
    // that is aligned with both zig good practice and the book
    // which is unfortunately abstracted all tbe inner details.

    // "override" your program using function pointer,
    // and the run function will process them all
    app.start_up = startup;
    app.render = render;
    app.shutdown = shutdown;
    app.run();
}

fn startup() callconv(.c) void {

    // Logs for build status
    var success: c_int = undefined;
    var infoLog: [512:0]u8 = undefined;

    // vertex shader
    const vs: app.gl.uint = app.gl.CreateShader(app.gl.VERTEX_SHADER);
    app.gl.ShaderSource(
        vs,
        1,
        &.{shader.vertexShaderImpl},
        &.{shader.vertexShaderImpl.len},
    );
    app.gl.CompileShader(vs);
    app.verifyShader(vs, &success, &infoLog) catch {
        return;
    };

    // fragment shader
    const fs: app.gl.uint = app.gl.CreateShader(app.gl.FRAGMENT_SHADER);
    app.gl.ShaderSource(
        fs,
        1,
        &.{shader.fragmentShaderImpl},
        &.{shader.fragmentShaderImpl.len},
    );
    app.gl.CompileShader(fs);
    app.verifyShader(fs, &success, &infoLog) catch {
        return;
    };

    // Now put all the shaders into the program
    program = app.gl.CreateProgram();
    app.gl.AttachShader(program, vs);
    app.gl.AttachShader(program, fs);

    app.gl.LinkProgram(program);

    // in the original c++ example, there are function calls to delete the shader after they are linked.
    // Seems like they are not deleted from the program immediately, but marked for deletion till
    // the shader is no longer attached from the program that leads to an actual deletion.
    app.gl.DeleteShader(vs);
    app.gl.DeleteShader(fs);

    app.verifyProgram(program, &success, &infoLog) catch {
        return;
    };

    // define uniforms. arrays and buffers:
    uni_mvp = app.gl.GetUniformLocation(program, "mvp");
    uni_offset = app.gl.GetUniformLocation(program, "offset");

    app.gl.GenVertexArrays(1, (&vao)[0..1]);
    app.gl.BindVertexArray(vao);

    // load and process textures:
    const page = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page);
    defer arena.deinit();

    _ = ktx.load(arena.allocator(), "src/media/textures/brick.ktx", &tex_wall) catch |err| {
        std.debug.print("Wall Texture Load Failed: {any}", .{err});
    };

    _ = ktx.load(arena.allocator(), "src/media/textures/ceiling.ktx", &tex_ceiling) catch |err| {
        std.debug.print("Ceiling Texture Load Failed: {any}", .{err});
    };

    _ = ktx.load(arena.allocator(), "src/media/textures/floor.ktx", &tex_floor) catch |err| {
        std.debug.print("Floor Texture Load Failed: {any}", .{err});
    };

    const textures = [3]app.gl.uint{ tex_floor, tex_wall, tex_ceiling };

    // try to use inline loop to replace the original runtime loop in C++
    inline for (textures) |texture| {
        app.gl.BindTexture(app.gl.TEXTURE_2D, texture);

        // apply linear smoothing with linear mipmap when the texture is applied into a very small plane
        // mipmap is the reduced version of the original texture, and it has multiple level of reduction such that
        // the texture will not flash unexpectedly due to clamping a large texture into a small space.
        app.gl.TexParameteri(app.gl.TEXTURE_2D, app.gl.TEXTURE_MIN_FILTER, app.gl.LINEAR_MIPMAP_LINEAR);

        // apply linear smoothing only when the plane gets larger than the texture that requires zooming in
        app.gl.TexParameteri(app.gl.TEXTURE_2D, app.gl.TEXTURE_MAG_FILTER, app.gl.LINEAR);
    }
}

fn render(current_time: f64) callconv(.c) void {
    const black: [4]app.gl.float = .{ 0.0, 0.0, 0.0, 0.0 };
    app.gl.Viewport(0, 0, app.info.windowWidth, app.info.windowHeight);
    app.gl.ClearBufferfv(app.gl.COLOR, 0, &black);

    app.gl.UseProgram(program);

    // This uniform is used for shifting the texture outwards such that to create a moving in illusion
    app.gl.Uniform1f(uni_offset, @floatCast(current_time * 0.003));

    // use a perspective matrix, and remember the array orientation difference between zm and opengl.
    // This matrix is used for create the depth of the tunnel from a flat texture
    const proj_matrix = zm.Mat4f.perspective(
        std.math.degreesToRadians(60),
        @as(f32, @floatFromInt(app.info.windowWidth)) / @as(f32, @floatFromInt(app.info.windowHeight)),
        0.1,
        100,
    );

    // construct the four texture that represent the floor, ceiling and the wall of two sides
    const textures = [4]app.gl.uint{ tex_wall, tex_floor, tex_wall, tex_ceiling };

    // The reason we can do a for loop is that all four textures share the same size and shape,
    // but the rotation is different, so we can use the index to change the rotation of the texture
    // instead of drawing them individually, thus the aforementioned textures array.
    for (textures, 0..) |texture, i| {

        // C++ vmath use degree mode, but zm use radian mode, thus the conversion
        // Also, be aware of the type of the matrix. the Mat4 in glsl and vmath (f32 based) is
        // different from the zig mat4 (f64 based). The type difference will not return any error,
        // but the shader will simply return a black screen if the float type of a matrix
        // is not the same.

        const mv_pt1 = zm.Mat4f.rotation(zm.Vec3f{ 0, 0, 1 }, std.math.degreesToRadians(90) * @as(f32, @floatFromInt(i)));
        const mv_pt2 = zm.Mat4f.translation(-0.5, 0.0, -10);
        const mv_pt3 = zm.Mat4f.rotation(zm.Vec3{ 0, 1, 0 }, std.math.degreesToRadians(90));
        const mv_pt4 = zm.Mat4f.scaling(30.0, 1.0, 1.0);
        const mv_matrix = mv_pt1.multiply(mv_pt2).multiply(mv_pt3).multiply(mv_pt4);

        const mvp = proj_matrix.multiply(mv_matrix);

        app.gl.UniformMatrix4fv(uni_mvp, 1, app.gl.TRUE, @ptrCast(&mvp));
        app.gl.BindTexture(app.gl.TEXTURE_2D, texture);
        app.gl.DrawArrays(app.gl.TRIANGLE_STRIP, 0, 4);
    }
}

fn shutdown() callconv(.c) void {
    app.gl.BindVertexArray(0);
    app.gl.DeleteVertexArrays(1, (&vao)[0..1]);
    app.gl.DeleteProgram(program);
}
