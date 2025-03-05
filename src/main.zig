const std = @import("std");
const linear = @import("linear.zig");
const ray = @import("ray.zig");
const material = @import("material.zig");
const render = @import("render.zig");
const zstbi = @import("zstbi");

fn sample_scene(
    materials: *std.StringHashMap(material.Material),
    world_hittables: *ray.Hittable,
) !void {
    try materials.put("ground", .{
        .lambertian = .{
            .albedo = linear.Color3.initN(0.8, 0.8, 0.0),
        },
    });
    try materials.put("center", .{
        .lambertian = .{
            .albedo = linear.Color3.initN(0.1, 0.2, 0.5),
        },
    });
    try materials.put("left", .{
        .dielectric = .{
            .refraction_index = 1.5,
        },
    });
    try materials.put("bubble", .{
        .dielectric = .{
            .refraction_index = 1.0 / 1.5,
        },
    });
    try materials.put("right", .{
        .metal = .{
            .albedo = linear.Color3.initN(0.8, 0.6, 0.2),
            .fuzz = 1.0,
        },
    });

    try world_hittables.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, -100.5, -1),
        .radius = 100,
        .mat = materials.getPtr("ground") orelse unreachable,
    } });
    try world_hittables.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, 0, -1.2),
        .radius = 0.5,
        .mat = materials.getPtr("center") orelse unreachable,
    } });
    try world_hittables.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(-1.0, 0, -1.0),
        .radius = 0.5,
        .mat = materials.getPtr("left") orelse unreachable,
    } });
    try world_hittables.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(-1.0, 0, -1.0),
        .radius = 0.4,
        .mat = materials.getPtr("bubble") orelse unreachable,
    } });
    try world_hittables.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(1.0, 0, -1.0),
        .radius = 0.5,
        .mat = materials.getPtr("right") orelse unreachable,
    } });
}

pub fn main() !void {
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.debug.print("Leak detected!\n", .{});
    }

    // Image
    const aspect_ration: comptime_float = 16.0 / 9.0;
    const image_width: comptime_int = 400;
    const samples_per_pixel: comptime_int = 100;

    // Materials
    var materials = std.StringHashMap(material.Material).init(gpa.allocator());
    defer materials.deinit();

    // World
    const _hittables = std.ArrayList(ray.Hittable).init(gpa.allocator());
    defer _hittables.deinit();
    var world = ray.Hittable{ .many = _hittables };
    try sample_scene(&materials, &world);

    // Random
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rand = prng.random();

    // Camera
    const CameraType = render.Camera(
        image_width,
        aspect_ration,
        3,
        samples_per_pixel,
    );
    const camera = CameraType.init(
        rand,
        20,
        linear.Point3.initN(-2.0, 2.0, 1.0),
        linear.Point3.initN(0.0, 0.0, -1.0),
        linear.Vec3.initN(0.0, 1.0, 0.0),
        10.0,
        3.4,
    );

    // Data
    var data: [CameraType.image_width * CameraType.image_height * CameraType.num_components]u8 = undefined;
    @memset(&data, 0);

    // Render
    camera.render(rand, world, &data);

    // Save
    zstbi.init(gpa.allocator());
    defer zstbi.deinit();
    const image: zstbi.Image = .{
        .data = &data,
        .width = image_width,
        .height = CameraType.image_height,
        .num_components = CameraType.num_components,
        .bytes_per_component = CameraType.bytes_per_component,
        .bytes_per_row = image_width * CameraType.num_components * CameraType.bytes_per_component,
        .is_hdr = false,
    };
    try image.writeToFile("image.png", .png);

    std.debug.print("\nDone.\n", .{});
}
