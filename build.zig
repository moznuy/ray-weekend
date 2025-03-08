const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const live = b.option(bool, "live", "enable live rendering with GLFW + OpenGL") orelse false;
    const options = b.addOptions();
    options.addOption(bool, "live", live);

    const exe = b.addExecutable(.{
        .name = "ray-zig1",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_thread = target.result.os.tag == .linux,
    });
    const queue_mod = b.addModule("SafeQueue", .{
        .root_source_file = b.path("src/SafeQueue.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("SafeQueue", queue_mod);

    if (live) {
        const live_mod = b.addModule("live", .{
            .root_source_file = b.path("src/live.zig"),
            .target = target,
            .optimize = optimize,
        });
        live_mod.addImport("SafeQueue", queue_mod);
        // const live_lib = b.addStaticLibrary(.{
        //     .name = "live",
        //     .root_source_file = b.path("src/live.zig"),
        //     .target = target,
        //     .optimize = optimize,
        // });

        const gl_bindings = @import("zigglgen").generateBindingsModule(b, .{
            .api = .gl,
            .version = .@"4.6",
            .profile = .core,
        });
        live_mod.addImport("gl", gl_bindings);
        live_mod.addIncludePath(b.path("libs/glfw-3.4/include"));
        live_mod.addLibraryPath(b.path("libs/glfw-3.4/lib-static-ucrt"));
        live_mod.linkSystemLibrary("glfw3dll", .{});
        // b.installBinFile("libs/glfw-3.4/lib-static-ucrt/glfw3.dll", "glfw3.dll");
        exe.root_module.addImport("live", live_mod);
        // exe.linkLibrary(live_lib);
    }

    const zstbi = b.dependency("zstbi", .{});
    exe.root_module.addOptions("config", options);
    exe.root_module.addImport("zstbi", zstbi.module("root"));
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
