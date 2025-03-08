const std = @import("std");
const SafeQueue = @import("SafeQueue");
const glfw = @cImport({
    @cDefine("GLFW_INCLUDE_NONE", {});
    @cInclude("GLFW/glfw3.h");
});
const gl = @import("gl");
var procs: gl.ProcTable = undefined;

fn error_callback(err: c_int, c_desc: [*c]const u8) callconv(.C) void {
    const desc = std.mem.span(c_desc);
    std.debug.print("Error {}: {s}\n", .{ err, desc });
}

fn framebuffer_size_callback(_: ?*glfw.GLFWwindow, w: c_int, h: c_int) callconv(.C) void {
    gl.Viewport(0, 0, w * 3, h * 3);
}

const width = 400;
const height = 225;

pub fn do_live(allocator: std.mem.Allocator, data: []u8, queue: *SafeQueue) !void {
    _ = glfw.glfwSetErrorCallback(error_callback);
    const my_data = try allocator.alloc(u8, data.len);
    defer allocator.free(my_data);
    @memset(my_data, 0);

    if (glfw.glfwInit() != glfw.GLFW_TRUE) return error.GlfwInit;
    defer glfw.glfwTerminate();

    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MAJOR, 4);
    glfw.glfwWindowHint(glfw.GLFW_CONTEXT_VERSION_MINOR, 6);
    glfw.glfwWindowHint(glfw.GLFW_OPENGL_PROFILE, glfw.GLFW_OPENGL_CORE_PROFILE);

    const window = glfw.glfwCreateWindow(width * 3, height * 3, "Test OpenGL", null, null);
    if (window == null) return error.InitWindow;
    defer glfw.glfwDestroyWindow(window);
    glfw.glfwMakeContextCurrent(window);

    if (!procs.init(glfw.glfwGetProcAddress)) return error.ZigglgenFail;
    gl.makeProcTableCurrent(&procs);
    defer gl.makeProcTableCurrent(null);

    const program = try compile_shaders();

    const vertices = [_]f32{
        1, 1, 0.0, 1.0, 0.0, 0.0, 1.0, 0.0, // top right
        1, -1, 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, // bottom right
        -1, -1, 0.0, 0.0, 0.0, 1.0, 0.0, 1.0, // bottom left
        -1, 1, 0.0, 1.0, 1.0, 0.0, 0.0, 0.0, // top left
    };
    const indices = [_]u8{ // note that we start from 0!
        0, 1, 3, // first Triangle
        1, 2, 3, // second Triangle
    };
    var VAO: [1]gl.uint = undefined;
    var VBO: [1]gl.uint = undefined;
    var EBO: [1]gl.uint = undefined;
    gl.GenVertexArrays(1, &VAO);
    gl.GenBuffers(1, &VBO);
    gl.GenBuffers(1, &EBO);
    gl.BindVertexArray(VAO[0]);

    gl.BindBuffer(gl.ARRAY_BUFFER, VBO[0]);
    gl.BufferData(gl.ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.STATIC_DRAW);

    gl.BindBuffer(gl.ELEMENT_ARRAY_BUFFER, EBO[0]);
    gl.BufferData(gl.ELEMENT_ARRAY_BUFFER, @sizeOf(@TypeOf(indices)), &indices, gl.STATIC_DRAW);

    gl.VertexAttribPointer(0, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 0);
    gl.EnableVertexAttribArray(0);
    gl.VertexAttribPointer(1, 3, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 3 * @sizeOf(f32));
    gl.EnableVertexAttribArray(1);
    gl.VertexAttribPointer(2, 2, gl.FLOAT, gl.FALSE, 8 * @sizeOf(f32), 6 * @sizeOf(f32));
    gl.EnableVertexAttribArray(2);

    gl.BindBuffer(gl.ARRAY_BUFFER, 0);
    gl.BindVertexArray(0);

    // const texture_data = try allocator.alloc(u8, height * width * comp_count * bytes_per_comp);
    // defer allocator.free(texture_data);
    // fillTexture(texture_data, 0);

    var texture: [2]gl.uint = undefined;
    gl.GenTextures(2, &texture);
    for (texture) |tex| {
        gl.BindTexture(gl.TEXTURE_2D, tex);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.REPEAT);
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR); // gl.LINEAR_MIPMAP_LINEAR
        gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
        gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, my_data.ptr);
    }
    // gl.GenerateMipmap(gl.TEXTURE_2D);

    gl.Viewport(0, 0, width * 3, height * 3);
    _ = glfw.glfwSetFramebufferSizeCallback(window, framebuffer_size_callback);
    var cur_tex_index: gl.uint = 0;

    while (glfw.glfwWindowShouldClose(window) != glfw.GLFW_TRUE) {
        processInput(window);
        const time = show_fps(window);
        _ = time; // autofix

        gl.ClearColor(0.2, 0.3, 0.3, 1.0);
        gl.Clear(gl.COLOR_BUFFER_BIT);

        const line_ready = queue.try_pop();
        if (line_ready) |line| {
            const src_from = line * width * 3 * 1;
            const src_to = (line + 1) * width * 3 * 1;
            // const dst_from = (height - line - 1) * width * 3 * 1;
            // const dst_to = (height - line - 1 + 1) * width * 3 * 1;

            @memcpy(my_data[src_from..src_to], data[src_from..src_to]);

            gl.BindTexture(gl.TEXTURE_2D, texture[1 - cur_tex_index]);
            gl.TexImage2D(gl.TEXTURE_2D, 0, gl.RGB, width, height, 0, gl.RGB, gl.UNSIGNED_BYTE, my_data.ptr);
            cur_tex_index = 1 - cur_tex_index;
        }

        gl.BindTexture(gl.TEXTURE_2D, texture[cur_tex_index]);
        gl.UseProgram(program);
        gl.BindVertexArray(VAO[0]);
        gl.DrawElements(gl.TRIANGLES, 6, gl.UNSIGNED_BYTE, 0);

        glfw.glfwSwapBuffers(window);
        glfw.glfwPollEvents();
    }
    return;
}

fn processInput(window: ?*glfw.GLFWwindow) void {
    if (glfw.glfwGetKey(window, glfw.GLFW_KEY_ESCAPE) == glfw.GLFW_PRESS)
        glfw.glfwSetWindowShouldClose(window, 1);
}

fn compile_shaders() !gl.uint {
    const vertexShader = gl.CreateShader(gl.VERTEX_SHADER);
    gl.ShaderSource(vertexShader, 1, &vertexShaderSourceArr, null);
    gl.CompileShader(vertexShader);

    var success: gl.int = undefined;
    var infoLog: [512]u8 = undefined;
    gl.GetShaderiv(vertexShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.GetShaderInfoLog(vertexShader, 512, null, &infoLog);
        const log: [*:0]u8 = @ptrCast(&infoLog);
        std.debug.print("Vertex shader fail: {s}\n", .{log});
        return error.VertexError;
    }

    const fragmentShader = gl.CreateShader(gl.FRAGMENT_SHADER);
    gl.ShaderSource(fragmentShader, 1, &fragmentShaderSourceArr, null);
    gl.CompileShader(fragmentShader);

    gl.GetShaderiv(fragmentShader, gl.COMPILE_STATUS, &success);
    if (success == 0) {
        gl.GetShaderInfoLog(fragmentShader, 512, null, &infoLog);
        const log: [*:0]u8 = @ptrCast(&infoLog);
        std.debug.print("Fragment shader fail: {s}\n", .{log});
        return error.FragmentError;
    }

    const shaderProgram: gl.uint = gl.CreateProgram();
    gl.AttachShader(shaderProgram, vertexShader);
    gl.AttachShader(shaderProgram, fragmentShader);
    gl.LinkProgram(shaderProgram);
    // check for linking errors
    gl.GetProgramiv(shaderProgram, gl.LINK_STATUS, &success);
    if (success == 0) {
        gl.GetProgramInfoLog(shaderProgram, 512, null, &infoLog);
        const log: [*:0]u8 = @ptrCast(&infoLog);
        std.debug.print("Program fail: {s}\n", .{log});
    }
    gl.DeleteShader(vertexShader);
    gl.DeleteShader(fragmentShader);
    return shaderProgram;
}

const Time = struct {
    dt: f64,
    elapsed: f64,
};
var lastTime: f64 = 0;
var nbFrames: u64 = 0;
fn show_fps(window: ?*glfw.GLFWwindow) Time {
    const currTime = glfw.glfwGetTime();
    const delta = currTime - lastTime;
    const res = Time{ .dt = delta, .elapsed = currTime };
    nbFrames += 1;
    if (delta < 1.0) return res;

    const fps = @as(f64, @floatFromInt(nbFrames)) / delta;
    // std.debug.print("{d:0.1}\n", .{fps});
    nbFrames = 0;
    lastTime = currTime;
    var buff: [64]u8 = undefined;
    // const alloc = std.heap.FixedBufferAllocator.init(buff).allocator();
    const data = std.fmt.bufPrintZ(&buff, "FPS: {d:0.1}\x00", .{fps}) catch unreachable;
    glfw.glfwSetWindowTitle(window, data);
    return res;
}

const vertexShaderSource =
    \\#version 330 core
    \\layout (location = 0) in vec3 aPos;
    \\layout (location = 1) in vec3 aColor;
    \\layout (location = 2) in vec2 aTexCoord;
    \\
    \\out vec3 ourColor;
    \\out vec2 TexCoord;
    \\void main()
    \\{
    \\  gl_Position = vec4(aPos, 1.0);
    \\  ourColor = aColor;
    \\  TexCoord = aTexCoord;
    \\}
;

const vertexShaderSourceArr = [_][*]const u8{vertexShaderSource};
const fragmentShaderSource =
    \\#version 330 core
    \\out vec4 FragColor;
    \\
    \\in vec3 ourColor;
    \\in vec2 TexCoord;
    \\
    \\uniform sampler2D ourTexture;
    \\
    \\void main()
    \\{
    \\  // FragColor = vec4(1.0f, 0.5f, 0.2f, 1.0f);
    \\  FragColor = texture(ourTexture, TexCoord);
    \\}
;
const fragmentShaderSourceArr = [_][*]const u8{fragmentShaderSource};
