// This is actually not the idiomatic way to write shaders which they have
// their own file format, but to prevent the main program too cluttered,
// let me locate the shaders in here.

// Vertex Shader, plotting the location of the vertices.
pub const vertexShaderImpl =
    \\ #version 450 core
    \\
    \\ out VS_OUT
    \\ {
    \\     vec2 tc;
    \\ } vs_out;
    \\
    \\ uniform mat4 mvp;
    \\ uniform float offset;
    \\
    \\ void main (void)
    \\ {   
    \\     // Define a rectangle such that we can draw a texture on it
    \\     const vec4 vertices[] = vec4[](vec2(-0.5, -0.5),
    \\                                    vec2(-0.5, -0.5),
    \\                                    vec2(-0.5, -0.5),
    \\                                    vec2(-0.5, -0.5));
    \\
    \\     // I have no idea what happened to these code, I will take a research for it 
    \\     vs_out.tc = (position[gl_VertexID].xy + vec2(offset, 0.5)) * vec2(30, 1.0);
    \\     gl_Position = mvp * vec4(vertices[gl_VertexID], 0.0, 1.0);
    \\ }
;

// fragment Shader, changing the color of the the geometries
pub const fragmentShaderImpl =
    \\ #version 450 core
    \\ 
    \\ layout (location = 0) out vec4 color;
    \\ 
    \\ // Take the VS_OUT structure from the vertex shader as input
    \\ in VS_OUT{
    \\     vec2 tc;
    \\ } fs_in;
    \\ 
    \\ layout (binding = 0) uniform sampler2D tex;
    \\ 
    \\ void main(void)
    \\ {   
    \\     // with the fs_in.tc, the texture will repeat 30 times
    \\     // due to the multiple and the wrapping behavior.
    \\     color = texture(tex, fs_in.tc);
    \\ }
;
