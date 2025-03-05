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

fn final_scene(
    materials: *std.StringHashMap(material.Material),
    world: *ray.Hittable,
    rand: std.Random,
    allocator: std.mem.Allocator,
) !void {
    try materials.put("ground", .{ .lambertian = .{
        .albedo = linear.Color3.initN(0.5, 0.5, 0.5),
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, -1000, 0),
        .radius = 1000,
        .mat_name = "ground",
    } });

    const arb_point = linear.Point3.initN(4, 0.2, 0);
    var a: i64 = -11;

    while (a < 11) : (a += 1) {
        var b: i64 = -11;
        while (b < 11) : (b += 1) {
            const choose_mat = rand.float(f64);
            const center = linear.Point3.initN(
                @as(f64, @floatFromInt(a)) + 0.9 * rand.float(f64),
                0.2,
                @as(f64, @floatFromInt(b)) + 0.9 * rand.float(f64),
            );

            if (center.sub(arb_point).length() <= 0.9) {
                continue;
            }

            const mat_name = try std.fmt.allocPrint(allocator, "dyn-{}-{}", .{ a, b });
            if (choose_mat < 0.8) {
                // diffuse
                const albedo = linear.random_vec(rand).mul(linear.random_vec(rand));
                try materials.put(mat_name, .{ .lambertian = .{ .albedo = albedo } });
                try world.many.append(.{ .sphere = .{ .center = center, .radius = 0.2, .mat_name = mat_name } });
            } else if (choose_mat < 0.95) {
                //metal
                const albedo = linear.random_vec_range(rand, 0.5, 1);
                const fuzz = rand.float(f64);
                try materials.put(mat_name, .{ .metal = .{ .albedo = albedo, .fuzz = fuzz } });
                try world.many.append(.{ .sphere = .{ .center = center, .radius = 0.2, .mat_name = mat_name } });
            } else {
                //glass
                try materials.put(mat_name, .{ .dielectric = .{ .refraction_index = 1.5 } });
                try world.many.append(.{ .sphere = .{ .center = center, .radius = 0.2, .mat_name = mat_name } });
            }
        }
    }

    try materials.put("big-sphere1", .{ .dielectric = .{
        .refraction_index = 1.5,
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, 1, 0),
        .radius = 1.0,
        .mat_name = "big-sphere1",
    } });
    try materials.put("big-sphere2", .{ .lambertian = .{
        .albedo = linear.Color3.initN(0.4, 0.2, 0.1),
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(-4, 1, 0),
        .radius = 1.0,
        .mat_name = "big-sphere2",
    } });
    try materials.put("big-sphere3", .{ .metal = .{
        .albedo = linear.Color3.initN(0.7, 0.6, 0.5),
        .fuzz = 0.0,
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(4, 1, 0),
        .radius = 1.0,
        .mat_name = "big-sphere3",
    } });
}

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

    // Materials
    var materials = std.StringHashMap(material.Material).init(gpa.allocator());
    defer materials.deinit();

    // World
    const _hittables = std.ArrayList(ray.Hittable).init(gpa.allocator());
    var world = ray.Hittable{ .many = _hittables };
    defer world.many.deinit();

    // try sample_scene(&materials, &world);

    var mat_names_buf: [4096]u8 = undefined;
    var mat_name_allocator = std.heap.FixedBufferAllocator.init(&mat_names_buf);
    try final_scene(&materials, &world, rand, mat_name_allocator.allocator());

    materials.lockPointers();
    defer materials.unlockPointers();

    // Camera
    const CameraType = render.Camera(
        16.0 / 9.0,
        400,
        3,
        100,
        50,
    );
    // const camera = CameraType.init(
    //     rand,
    //     20,
    //     linear.Point3.initN(-2.0, 2.0, 1.0),
    //     linear.Point3.initN(0.0, 0.0, -1.0),
    //     linear.Vec3.initN(0.0, 1.0, 0.0),
    //     10.0,
    //     3.4,
    //     &materials,
    // );
    const camera = CameraType.init(
        20,
        linear.Point3.initN(13, 2.0, 3.0),
        linear.Point3.initN(0.0, 0.0, 0.0),
        linear.Vec3.initN(0.0, 1.0, 0.0),
        0.6,
        10,
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
        .width = CameraType.image_width,
        .height = CameraType.image_height,
        .num_components = CameraType.num_components,
        .bytes_per_component = CameraType.bytes_per_component,
        .bytes_per_row = CameraType.image_width * CameraType.num_components * CameraType.bytes_per_component,
        .is_hdr = false,
    };
    try image.writeToFile("image.png", .png);

    std.debug.print("\nDone.\n", .{});
}
