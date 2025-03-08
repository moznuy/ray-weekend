const std = @import("std");
const linear = @import("linear.zig");
const ray = @import("ray.zig");
const material = @import("material.zig");
const render = @import("render.zig");
const SafeQueue = @import("SafeQueue");
const zstbi = @import("zstbi");
const config = @import("config");

fn sample_scene(
    materials: *std.StringHashMap(material.Material),
    world: *ray.Hittable,
) !render.Camera {
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

    const image_params = render.ImageParams.init(16.0 / 9.0, 400);
    const camera = render.Camera.init(
        20,
        linear.Point3.initN(-2.0, 2.0, 1.0),
        linear.Point3.initN(0.0, 0.0, -1.0),
        linear.Vec3.initN(0.0, 1.0, 0.0),
        10.0,
        3.4,
        100,
        50,
        image_params,
        materials,
    );
    return camera;
}

fn final_scene(
    materials: *std.StringHashMap(material.Material),
    world: *ray.Hittable,
    allocator: std.mem.Allocator,
) !render.Camera {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rand = prng.random();

    try materials.put("ground", .{ .lambertian = .{
        .albedo = linear.Color3.initN(0.5, 0.5, 0.5),
    } });
    try world.many.append(.{ .sphere = .{
        .center = linear.Point3.initN(0, -1000, 0),
        .radius = 1000,
        .mat_name = "ground",
    } });

    const sphere1 = linear.Point3.initN(0, 1, 0);
    const sphere2 = linear.Point3.initN(-4, 1, 0);
    const sphere3 = linear.Point3.initN(4, 1, 0);

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

            if (center.sub(sphere1).length() <= 1.2 or
                center.sub(sphere2).length() <= 1.2 or
                center.sub(sphere3).length() <= 1.2)
            {
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
        .center = sphere1,
        .radius = 1.0,
        .mat_name = "big-sphere1",
    } });
    try materials.put("big-sphere2", .{ .lambertian = .{
        .albedo = linear.Color3.initN(0.4, 0.2, 0.1),
    } });
    try world.many.append(.{ .sphere = .{
        .center = sphere2,
        .radius = 1.0,
        .mat_name = "big-sphere2",
    } });
    try materials.put("big-sphere3", .{ .metal = .{
        .albedo = linear.Color3.initN(0.7, 0.6, 0.5),
        .fuzz = 0.0,
    } });
    try world.many.append(.{ .sphere = .{
        .center = sphere3,
        .radius = 1.0,
        .mat_name = "big-sphere3",
    } });

    const image_params = render.ImageParams.init(16.0 / 9.0, 400);
    const camera = render.Camera.init(
        20,
        linear.Point3.initN(13, 2.0, 3.0),
        linear.Point3.initN(0.0, 0.0, 0.0),
        linear.Vec3.initN(0.0, 1.0, 0.0),
        0.6,
        10,
        100,
        50,
        image_params,
        materials,
    );
    return camera;
}

fn progress(lines_to_do: *std.atomic.Value(u64)) void {
    while (true) {
        const todo = lines_to_do.load(.monotonic);
        if (todo == 0) {
            break;
        }
        std.debug.print("\rScanlines remaining: {d:04}", .{todo});
        std.time.sleep(1 * std.time.ns_per_s);
    }
    std.debug.print("\n", .{});
}

pub fn main() !void {
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.debug.print("Leak detected!\n", .{});
    }

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len < 2) {
        std.debug.print("Usage: <program> <scene>\n", .{});
        return error.Usage;
    }
    const scene = args[1];

    // Materials
    var materials = std.StringHashMap(material.Material).init(allocator);
    defer materials.deinit();

    // World
    const _hittables = std.ArrayList(ray.Hittable).init(allocator);
    var world = ray.Hittable{ .many = _hittables };
    defer world.many.deinit();

    const camera = blk: {
        if (std.mem.eql(u8, scene, "sample")) {
            break :blk try sample_scene(&materials, &world);
        } else if (std.mem.eql(u8, scene, "final")) {
            // var mat_names_buf: [4096]u8 = undefined;
            // var mat_name_allocator = std.heap.FixedBufferAllocator.init(&mat_names_buf);
            break :blk try final_scene(&materials, &world, allocator);
        } else {
            return error.InvalidScene;
        }
    };

    materials.lockPointers();
    defer materials.unlockPointers();

    // Data
    const data = try allocator.alloc(u8, camera.image_params.bytes_needed);
    defer allocator.free(data);
    @memset(data, 0);

    var queue = SafeQueue.init(allocator);
    defer queue.deinit();

    std.debug.print("Compiled with live({})\n", .{config.live});
    if (!config.live) {
        try do_render(allocator, camera, world, data, &queue);
        return;
    }
    const render_thread = try std.Thread.spawn(.{}, do_render, .{ allocator, camera, world, data, &queue });
    defer render_thread.join();

    const live = @import("live");
    // std.debug.print("{} {}\n", .{ camera.image_params.image_width, camera.image_params.image_height });
    try live.do_live(allocator, data, &queue);
}

fn do_render(allocator: std.mem.Allocator, camera: render.Camera, world: ray.Hittable, data: []u8, queue: *SafeQueue) !void {
    // Render
    // camera.render(world, &data, 0, 1);
    var pool: std.Thread.Pool = undefined;
    try pool.init(.{
        .allocator = allocator,
        .n_jobs = @intCast(try std.Thread.getCpuCount() * 2 / 3),
    });
    var lines_to_do: std.atomic.Value(u64) = undefined;
    lines_to_do.store(camera.image_params.image_height, .monotonic);
    const progress_thread = try std.Thread.spawn(.{}, progress, .{&lines_to_do});
    const height = camera.image_params.image_height;
    for (0..height) |line| {
        try pool.spawn(render.Camera.render, .{ camera, world, data, height - line - 1, &lines_to_do, queue });
    }
    pool.deinit();
    progress_thread.join();

    // Save
    zstbi.init(allocator);
    defer zstbi.deinit();
    const image: zstbi.Image = .{
        .data = data,
        .width = camera.image_params.image_width,
        .height = camera.image_params.image_height,
        .num_components = camera.image_params.num_components,
        .bytes_per_component = camera.image_params.bytes_per_component,
        .bytes_per_row = camera.image_params.image_width * camera.image_params.num_components * camera.image_params.bytes_per_component,
        .is_hdr = false,
    };
    try image.writeToFile("image.png", .png);
}
