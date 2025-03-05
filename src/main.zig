const std = @import("std");
const linear = @import("linear.zig");
const ray = @import("ray.zig");
const material = @import("material.zig");
const render = @import("render.zig");
const zstbi = @import("zstbi");

pub fn main() !void {
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.debug.print("Leak detected!", .{});
    }

    // Image
    const aspect_ration: comptime_float = 16.0 / 9.0;
    const image_width: comptime_int = 400;
    const samples_per_pixel: comptime_int = 100;

    // Materials
    const material_ground = material.Material{
        .lambertian = .{
            .albedo = linear.Color3.initN(0.8, 0.8, 0.0),
        },
    };
    const material_center = material.Material{
        .lambertian = .{
            .albedo = linear.Color3.initN(0.1, 0.2, 0.5),
        },
    };
    const material_left = material.Material{
        .dielectric = .{
            .refraction_index = 1.5,
        },
    };
    const material_bubble = material.Material{
        .dielectric = .{
            .refraction_index = 1.0 / 1.5,
        },
    };
    const material_right = material.Material{
        .metal = .{
            .albedo = linear.Color3.initN(0.8, 0.6, 0.2),
            .fuzz = 1.0,
        },
    };
    // const material_left = material.Material{
    //     .lambertian = .{
    //         .albedo = linear.Color3.initN(0, 0, 1),
    //     },
    // };
    // const material_right = material.Material{
    //     .lambertian = .{
    //         .albedo = linear.Color3.initN(1, 0, 0),
    //     },
    // };

    // World
    const _hittables = try std.ArrayList(ray.Hittable).initCapacity(gpa.allocator(), 5);
    defer _hittables.deinit();

    var world = ray.Hittable{ .many = _hittables };
    // const R = std.math.cos(std.math.pi / 4.0);
    // world.many.appendAssumeCapacity(.{
    //     .sphere = .{
    //         .center = linear.Point3.initN(-R, 0, -1),
    //         .radius = R,
    //         .mat = &material_left,
    //     },
    // });
    // world.many.appendAssumeCapacity(.{
    //     .sphere = .{
    //         .center = linear.Point3.initN(R, 0, -1),
    //         .radius = R,
    //         .mat = &material_right,
    //     },
    // });
    world.many.appendAssumeCapacity(.{ .sphere = .{
        .center = linear.Point3.initN(0, -100.5, -1),
        .radius = 100,
        .mat = &material_ground,
    } });
    world.many.appendAssumeCapacity(.{ .sphere = .{
        .center = linear.Point3.initN(0, 0, -1.2),
        .radius = 0.5,
        .mat = &material_center,
    } });
    world.many.appendAssumeCapacity(.{ .sphere = .{
        .center = linear.Point3.initN(-1.0, 0, -1.0),
        .radius = 0.5,
        .mat = &material_left,
    } });
    world.many.appendAssumeCapacity(.{ .sphere = .{
        .center = linear.Point3.initN(-1.0, 0, -1.0),
        .radius = 0.4,
        .mat = &material_bubble,
    } });
    world.many.appendAssumeCapacity(.{ .sphere = .{
        .center = linear.Point3.initN(1.0, 0, -1.0),
        .radius = 0.5,
        .mat = &material_right,
    } });

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
