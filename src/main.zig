const std = @import("std");
const linear = @import("linear.zig");
const ray = @import("ray.zig");
const material = @import("material.zig");
const render = @import("render.zig");
const zstbi = @import("zstbi");

fn sample_scene(
    materials: *std.StringHashMap(material.Material),
    world: *ray.Hittable,
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

    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, -100.5, -1),
        .radius = 100,
        .mat_name = "ground",
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, 0, -1.2),
        .radius = 0.5,
        .mat_name = "center",
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(-1.0, 0, -1.0),
        .radius = 0.5,
        .mat_name = "left",
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(-1.0, 0, -1.0),
        .radius = 0.4,
        .mat_name = "bubble",
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(1.0, 0, -1.0),
        .radius = 0.5,
        .mat_name = "right",
    } });
}

// fn final_scene(
//     materials: *std.StringHashMap(material.Material),
//     world: *ray.Hittable,
//     rand: std.Random,
// ) !void {
//     try materials.put("ground", .{ .lambertian = .{
//         .albedo = linear.Color3.initN(0.5, 0.5, 0.5),
//     } });
//     try world.many.append(.{ .sphere = .{
//         .center = linear.Point3.initN(0, -1000, 0),
//         .radius = 1000,
//         .mat = materials.getPtr("ground") orelse unreachable,
//     } });

//     const arb_point = linear.Point3.initN(4, 0.2, 0);
//     var a: i64 = -11;
//     var buff: u8[20]
//     while (a < 11) : (a += 1) {
//         var b: i64 = -11;
//         while (b < 11) : (b += 1) {
//             const choose_mat = rand.float(f64);
//             const center = linear.Point3.initN(
//                 @as(f64, @floatFromInt(a)) + 0.9 * rand.float(f64),
//                 0.2,
//                 @as(f64, @floatFromInt(b)) + 0.9 * rand.float(f64),
//             );

//             if (center.sub(arb_point).length() <= 0.9) {
//                 continue;
//             }

//             if (choose_mat < 0.8) {
//                 // diffuse
//             } else if (choose_mat < 0.95) {
//                 //metal
//             } else {
//                 //glass
//             }
//         }
//     }
// }

pub fn main() !void {
    // Random
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rand = prng.random();

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
    materials.lockPointers();
    defer materials.unlockPointers();
    // try final_scene(&materials, &world, rand);

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
        &materials,
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
