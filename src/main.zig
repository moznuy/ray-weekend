const std = @import("std");

pub fn main() !void {
    const image_width = 256;
    const image_height = 256;

    var file = try std.fs.cwd().openFile("image.ppm", .{ .mode = .write_only });
    defer file.close();
    // const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(file.writer());
    const stdout = bw.writer();

    try stdout.print("P3\n{d} {d}\n255\n", .{ image_width, image_height });
    for (0..image_height) |j| {
        std.debug.print("\rScanlines remaining: {d:04}", .{image_height - j});
        for (0..image_width) |i| {
            const r: f64 = @as(f64, @floatFromInt(i)) / (image_width - 1);
            const g: f64 = @as(f64, @floatFromInt(j)) / (image_height - 1);
            const b = 0.0;

            const ir: u8 = @intFromFloat(255.999 * r);
            const ig: u8 = @intFromFloat(255.999 * g);
            const ib: u8 = @intFromFloat(255.999 * b);

            try stdout.print("{d} {d} {d}\n", .{ ir, ig, ib });
        }
    }

    try bw.flush();
    std.debug.print("\rDone.\n", .{});
}
