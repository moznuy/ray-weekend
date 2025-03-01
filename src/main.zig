const std = @import("std");
const zstbi = @import("zstbi");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.debug.print("Leak detected!", .{});
    }
    zstbi.init(gpa.allocator());
    defer zstbi.deinit();

    const image_width = 256;
    const image_height = 256;
    const num_components = 3;
    const bytes_per_component = @sizeOf(u8);

    var data: [image_width * image_height * num_components]u8 = undefined;
    @memset(&data, 0);

    // var file = try std.fs.cwd().openFile("image.ppm", .{ .mode = .write_only });
    // defer file.close();
    // // const stdout_file = std.io.getStdOut().writer();
    // var bw = std.io.bufferedWriter(file.writer());
    // const stdout = bw.writer();

    // try stdout.print("P3\n{d} {d}\n255\n", .{ image_width, image_height });
    for (0..image_height) |i| {
        std.debug.print("\rScanlines remaining: {d:04}", .{image_height - i});
        for (0..image_width) |j| {
            const r: f64 = @as(f64, @floatFromInt(j)) / (image_width - 1);
            const g: f64 = @as(f64, @floatFromInt(i)) / (image_height - 1);
            const b = 0.0;

            const ir: u8 = @intFromFloat(255.999 * r);
            const ig: u8 = @intFromFloat(255.999 * g);
            const ib: u8 = @intFromFloat(255.999 * b);

            // try stdout.print("{d} {d} {d}\n", .{ ir, ig, ib });
            data[(i * image_width + j) * num_components] = ir;
            data[(i * image_width + j) * num_components + 1] = ig;
            data[(i * image_width + j) * num_components + 2] = ib;
        }
    }

    const image: zstbi.Image = .{
        .data = &data,
        .width = image_width,
        .height = image_height,
        .num_components = num_components,
        .bytes_per_component = bytes_per_component,
        .bytes_per_row = image_width * num_components * bytes_per_component,
        .is_hdr = false,
    };
    try image.writeToFile("try.png", .png);

    // try bw.flush();
    std.debug.print("\nDone.\n", .{});
}
