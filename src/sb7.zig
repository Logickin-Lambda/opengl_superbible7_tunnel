/// Warning:
///
/// I have been searching for a better alternative to those function pointers,
/// into a more directed way to write the examples; unfortunately, aligning to the
/// original superbible is another requirement into this project, exposing the
/// similar code structure and function instead of writing the most optimal
/// and concise code which is definitely not ideal.
///
/// This is definitely not an idiomatic way to write zig, and I would also
/// discourage the use of function pointer, but because the OpenGL superbible
/// has no explanation into the project set up or the sb7.h while many of
/// the section in the book heavily relying on this header, I have no choice
/// but writing in such style; otherwise, people would never understand what
/// "override your on_debug_message() function in the given sb7.h", or
/// "simply attach your 'sb7.h' and calls the 'run()' function that drives
/// the inner main even loop".
///
/// If you actually want to start your project, you should write in a more direct way,
/// instead of my current, the "bandage to the problem" way just to compatible with the book:
/// For example:
/// - https://github.com/Logickin-Lambda/learn_opengl_first_triangle/blob/main/src/main.zig
/// - https://github.com/castholm/zig-examples/tree/master/opengl-hexagon
/// - https://github.com/griush/zig-opengl-example/blob/master/src/main.zig
///
/// Don't blindly trust a source, wisely evaluate different examples and
/// discuss with thecommunity to seek a better practice.
///
const std = @import("std");
const builtin = @import("builtin");
const debugapi = @cImport({
    @cInclude("debugapi.h");
});

pub const glfw = @import("zglfw");
pub const gl = @import("gl");

const FLAGS = struct {
    fullscreen: c_uint = 0,
    vsync: c_uint = 0,
    cursor: c_uint = 0,
    stereo: c_uint = 0,
    debug: c_uint = 0,
    robust: c_uint = 0,
};

const APPINFO = struct {
    title: [128]u8 = undefined,
    windowWidth: c_int = 800,
    windowHeight: c_int = 600,
    majorVersion: c_int = 4,
    minorversion: c_int = 5,
    samples: c_int = 0,
    flags: FLAGS,
};

pub var info = APPINFO{ .flags = FLAGS{} };
pub var window: *glfw.Window = undefined;

var procs: gl.ProcTable = undefined;

// public virtual functions to emulate constructor and destructor
pub var init: *const fn () anyerror!void = obj_virtual;
pub var deinit: *const fn () anyerror!void = obj_virtual;
fn obj_virtual() anyerror!void {
    return error.OperationNotSupportedError;
}

// others are the original methods from sb7.h
pub var start_up: *const fn () callconv(.c) void = undefined;
pub var render: *const fn (f64) callconv(.c) void = undefined;
pub var shutdown: *const fn () callconv(.c) void = undefined;
pub var on_resize: *const fn (*glfw.Window, c_int, c_int) callconv(.c) void = on_resize_impl;
pub var on_key: *const fn (*glfw.Window, glfw.Key, c_int, glfw.Action, glfw.Mods) callconv(.c) void = undefined;
pub var on_mouse_button: *const fn (*glfw.Window, glfw.MouseButton, glfw.Action, glfw.Mods) callconv(.c) void = undefined;
pub var on_mouse_move: *const fn (*glfw.Window, f64, f64) callconv(.c) void = undefined;
pub var on_mouse_wheel: *const fn (*glfw.Window, f64, f64) callconv(.c) void = undefined;
pub var get_mouse_position: *const fn (*glfw.Window, *c_int, *c_int) callconv(.c) void = undefined;
pub var glfw_onResize: *const fn (*glfw.Window, c_int, c_int) callconv(.c) void = undefined;
pub var on_debug_message: *const fn (gl.@"enum", gl.@"enum", gl.uint, gl.@"enum", gl.sizei, [*:0]const gl.char, ?*const anyopaque) callconv(.c) void = on_debug_message_impl;

// concrete functions:
// pub fn set_v_sync(enable: bool) void {}

pub fn set_window_title(title: [:0]const u8) void {
    glfw.setWindowTitle(window, title);
}

pub fn init_default() void {
    std.mem.copyForwards(u8, &info.title, "OpenGL SuperBible Example");
    info.windowWidth = 800;
    info.windowHeight = 600;

    // this is the zig version of
    // #ifdef __APPLE__
    if (comptime builtin.target.os.tag == .macos) {
        info.majorVersion = 3;
        info.minorversion = 2;
    }

    if (comptime builtin.mode == .Debug) {
        info.flags.debug = 1;
    }
}

fn on_debug_message_impl(_: gl.@"enum", _: gl.@"enum", _: gl.uint, _: gl.@"enum", _: gl.sizei, message: [*:0]const gl.char, _: ?*const anyopaque) callconv(.c) void {
    if (builtin.os.tag == .windows) {
        debugapi.OutputDebugStringA(message);
        debugapi.OutputDebugStringA(message);
    }
}

fn on_resize_impl(_: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
    info.windowWidth = w;
    info.windowHeight = h;
}

/// This is actually not a good code by the name because most of the function are related to
/// initialization of the glfw windows, which should belong to the init function.
pub fn run() void {
    var running = true;

    glfw.init() catch {
        std.log.err("GLFW initialization failed\n", .{});
        return;
    };
    defer glfw.terminate();

    init() catch |unknown_err| {
        if (unknown_err != error.OperationNotSupportedError) {
            std.log.err("Overridden APPINFO init function failed, using the default operation...\n", .{});
        }
        init_default();
    };

    glfw.windowHint(glfw.WindowHint.context_version_major, info.majorVersion);
    glfw.windowHint(glfw.WindowHint.context_version_minor, info.minorversion);

    if (builtin.mode != .Debug and (builtin.mode != .Debug and info.flags.debug == 1)) {
        glfw.windowHint(glfw.WindowHint.opengl_debug_context, gl.TRUE);
    }

    if (info.flags.robust == 1) {
        glfw.windowHint(glfw.WindowHint.context_robustness, glfw.ContextRobustness.lose_context_on_reset);
    }

    glfw.windowHint(glfw.WindowHint.opengl_profile, glfw.OpenGLProfile.opengl_core_profile);
    glfw.windowHint(glfw.WindowHint.opengl_forward_compat, true);
    glfw.windowHint(glfw.WindowHint.samples, info.samples);

    // since stereo contains 1 or 0 which is same as how OpenGL present its true and false value
    // we can squarely use the numerical values.
    const stereo = info.flags.stereo == gl.TRUE; // used for rendering VR, thus false by default for normal screen
    glfw.windowHint(glfw.WindowHint.stereo, stereo);

    // full screen handling are ignored in the original sb7.h code, so I will skip that part of code
    const is_full_screen: ?*glfw.Monitor = if (info.flags.fullscreen == gl.TRUE) glfw.getPrimaryMonitor() else null;

    window = glfw.createWindow(
        info.windowWidth,
        info.windowHeight,
        info.title[0.. :0],
        is_full_screen,
    ) catch |err| {
        std.log.err("GLFW Window creation failed: {any}", .{err});
        std.log.err("info.windowWidth: {d}", .{info.windowWidth});
        std.log.err("info.windowHeight: {d}", .{info.windowHeight});
        std.log.err("info.title: {s}", .{info.title});
        return;
    };
    defer window.destroy();

    glfw.makeContextCurrent(window);
    defer glfw.makeContextCurrent(null);

    _ = glfw.setWindowSizeCallback(window, on_resize);
    _ = glfw.setKeyCallback(window, on_key);
    _ = glfw.setMouseButtonCallback(window, on_mouse_button);
    _ = glfw.setCursorPosCallback(window, on_mouse_move);
    _ = glfw.setScrollCallback(window, on_mouse_wheel);

    if (info.flags.cursor != 1) {
        glfw.setInputMode(window, glfw.InputMode.cursor, glfw.Cursor.Mode.hidden) catch {
            std.debug.print("setInputMode failed", .{});
            return;
        };
    }

    // Since I don't have gl3, but I have the zig version of the gl library, I will use the zig implementation;
    // thus, the following code will be different, but I have tested in other project before which behave the same.
    // Source: https://github.com/Logickin-Lambda/learn_opengl_first_triangle

    if (!procs.init(glfw.getProcAddress)) {
        std.log.err("Get GL Proc Address failed", .{});
    }

    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    if (builtin.mode == .Debug) {
        std.debug.print("VENDOR: {s}\n", .{gl.GetString(gl.VENDOR).?});
        std.debug.print("VERSION: {s}\n", .{gl.GetString(gl.VERSION).?});
        std.debug.print("RENDERER: {s}\n", .{gl.GetString(gl.RENDERER).?});
    }

    // Since I have defaulted the OpenGL version to 4.3, I will skip ahead the version check
    // because I haven't figured out what is gl3w while glfw doesn't have IsSupported
    if (info.flags.debug == gl.TRUE) {
        // I can't tell if the debug message callback really works
        // because there is neither compilation error nor debug log
        gl.DebugMessageCallback(on_debug_message, &0);
        gl.Enable(gl.DEBUG_OUTPUT_SYNCHRONOUS);
    }

    start_up();

    while (running) {
        render(glfw.getTime());

        glfw.swapBuffers(window);
        glfw.pollEvents();

        running = running and (glfw.getKey(window, glfw.Key.escape) == .release);
        running = running and !glfw.windowShouldClose(window);
    }

    shutdown();
}

// Additional program that is not included in sb7.h, but useful for debugging:
pub fn verifyShader(shader: c_uint, success: *c_int, infoLog: [:0]u8) !void {
    gl.GetShaderiv(shader, gl.COMPILE_STATUS, success);

    if (success.* == gl.FALSE) {
        gl.GetShaderInfoLog(
            shader,
            @as(c_int, @intCast(infoLog.len)),
            null,
            infoLog.ptr,
        );
        std.log.err("{s}", .{std.mem.sliceTo(infoLog.ptr, 0)});
        return error.CompileVertexShaderFailed;
    }
}

pub fn verifyProgram(shaderProgram: c_uint, success: *c_int, infoLog: [:0]u8) !void {
    gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, success);

    if (success.* == gl.FALSE) {
        gl.GetProgramInfoLog(
            shaderProgram,
            @as(c_int, @intCast(infoLog.len)),
            null,
            infoLog.ptr,
        );
        std.log.err("{s}", .{infoLog});
        return error.LinkProgramFailed;
    }
}
