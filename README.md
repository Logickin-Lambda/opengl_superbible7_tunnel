# Warning:
The original intention of this project is to port the original C++ implementation of the OpenGL SuperBible into zig that is compatible with the book format, which shows the **main features of the gl library** and the **shader code**, but because of the ease of migrating the code while objects and inheritance is forbidden in zig, I have to use function pointer as an alternative.

This is a **strongly discouraged practice** because the idea of zig is to minimizing the hidden behavior, writing in a more directed way, and I also dissatisfied with this current implementation; however, for the time I have, porting sb7.h directly is a more efficient approach to learn from the gl example, so I don't really have a choice for now. My project other than superbible won't write like this, please don't copy the structure.

If you are not focusing on the shader and the gl part of the library, you **SHOULD** take other projects as an reference to set up your opengl with is corresponding windowing system with a more idiomatic way:

- https://github.com/Logickin-Lambda/learn_opengl_first_triangle/blob/main/src/main.zig
- https://github.com/castholm/zig-examples/tree/master/opengl-hexagon
- https://github.com/griush/zig-opengl-example/blob/master/src/main.zig

# OpenGL SuperBible 7th Edition Triangle Example
This is a basic example to show how the gl library plot a triangle and apply color with a series of shader, 
and the compilation process.

# Dependencies
This sb7.h port applied with three dependencies:

[castholm - zigglen](https://github.com/castholm/zigglgen)

[zig-gamedev - zglfw](https://github.com/zig-gamedev/zglfw)

[griush - zm](https://github.com/griush/zm)
