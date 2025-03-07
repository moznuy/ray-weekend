const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const exe = b.addExecutable(.{
        .name = "ray-zig1",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .sanitize_thread = target.result.os.tag == .linux,
    });
    const zstbi = b.dependency("zstbi", .{});
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
