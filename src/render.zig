const std = @import("std");
const linear = @import("linear.zig");
const material = @import("material.zig");
const ray = @import("ray.zig");

pub const white = linear.Color3.initN(1, 1, 1);
pub const blue = linear.Color3.initN(0.5, 0.7, 1);
pub const black = linear.Color3.initN(0, 0, 0);

threadlocal var prng: std.Random.DefaultPrng = undefined;
threadlocal var init_prng_once = std.once(init_prng);
fn init_prng() void {
    prng = std.Random.DefaultPrng.init(@as(u64, @intCast(std.time.milliTimestamp())) + std.Thread.getCurrentId() * 1000);
}

pub fn Camera(
    aspect_ration: comptime_float,
    _image_width: comptime_int,
    _num_components: comptime_int,
    samples_per_pixel: comptime_int,
    max_depth: comptime_int,
) type {
    const image_height_tmp: comptime_int = @intFromFloat(@as(comptime_float, @floatFromInt(_image_width)) / aspect_ration);
    const pixel_samples_scale: comptime_float = 1.0 / @as(comptime_float, @floatFromInt(samples_per_pixel));

    return struct {
        center: linear.Point3,
        pixel00_loc: linear.Point3,
        pixel_delta_u: linear.Vec3,
        pixel_delta_v: linear.Vec3,
        defocus_angle: f64,
        defocus_disk_u: linear.Vec3,
        defocus_disk_v: linear.Vec3,
        // todo: this should not be in Camera
        materials: *const std.StringHashMap(material.Material),

        pub const image_height: comptime_int = if (image_height_tmp < 0) 1 else image_height_tmp;
        pub const image_width: comptime_int = _image_width;
        pub const num_components: comptime_int = _num_components;
        pub const bytes_per_component: comptime_int = @sizeOf(u8);

        const Self = @This();

        pub fn render(camera: Self, world: ray.Hittable, data: []u8, line: usize, lines_to_do: *std.atomic.Value(u64)) void {
            init_prng_once.call();
            const rand = prng.random();
            const i = line;
            for (0..image_width) |j| {
                var pixel_color = linear.Color3.initN(0, 0, 0);
                for (0..samples_per_pixel) |_| {
                    const _ray = camera.get_ray(rand, i, j);
                    pixel_color.accumulate(camera.ray_color(rand, max_depth, _ray, world));
                }

                set_color(data, pixel_color.scale(pixel_samples_scale), i, j, image_width, num_components);
            }
            _ = lines_to_do.fetchSub(1, .monotonic);
        }

        pub fn init(
            vfov: f64,
            look_from: linear.Point3,
            look_at: linear.Point3,
            v_up: linear.Vec3,
            defocus_angle: f64,
            focus_dist: f64,
            materials: *const std.StringHashMap(material.Material),
        ) Self {
            const theta = std.math.degreesToRadians(vfov);
            const h = std.math.tan(theta / 2.0);
            const viewport_height = 2.0 * h * focus_dist;
            const viewport_width = viewport_height * (@as(comptime_float, @floatFromInt(image_width)) / @as(comptime_float, @floatFromInt(image_height)));

            const w = look_from.sub(look_at).unit();
            const u = v_up.cross(w).unit();
            const v = w.cross(u);

            const viewport_u = u.scale(viewport_width);
            const viewport_v = v.scale(-viewport_height);

            const pixel_delta_u = viewport_u.scale(1.0 / @as(f64, @floatFromInt(image_width)));
            const pixel_delta_v = viewport_v.scale(1.0 / @as(f64, @floatFromInt(image_height)));

            const center = look_from;
            const viewport_upper_left = center
                .sub(w.scale(focus_dist))
                .sub(viewport_u.scale(0.5))
                .sub(viewport_v.scale(0.5));
            const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5));

            const defocus_radius = focus_dist * std.math.tan(std.math.degreesToRadians(defocus_angle / 2.0));
            const defocus_disk_u = u.scale(defocus_radius);
            const defocus_disk_v = v.scale(defocus_radius);

            const camera = Self{
                .center = center,
                .pixel00_loc = pixel00_loc,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .defocus_angle = defocus_angle,
                .defocus_disk_u = defocus_disk_u,
                .defocus_disk_v = defocus_disk_v,
                .materials = materials,
            };
            return camera;
        }

        pub fn get_ray(camera: Self, rand: std.Random, i: usize, j: usize) ray.Ray3 {
            // Construct a camera ray originating from the defocus disk and directed at a randomly
            // sampled point around the pixel location i, j.
            const offset = sample_square(rand);
            const pixel_sample = camera.pixel00_loc
                .add(camera.pixel_delta_u.scale(@as(f64, @floatFromInt(j)) + offset.x()))
                .add(camera.pixel_delta_v.scale(@as(f64, @floatFromInt(i)) + offset.y()));
            const ray_origin = if (camera.defocus_angle <= 0) camera.center else camera.sample_defocus_disk(rand);
            const ray_direction = pixel_sample.sub(ray_origin);

            return .{ .orig = ray_origin, .dir = ray_direction };
        }

        pub fn ray_color(camera: Self, rand: std.Random, depth: u64, _ray: ray.Ray3, hittable: ray.Hittable) linear.Color3 {
            // If we've exceeded the ray bounce limit, no more light is gathered.
            if (depth <= 0)
                return linear.Color3.initN(0, 0, 0);

            if (hittable.hit(camera.materials, _ray, ray.Interval{ .min = 0.001, .max = std.math.floatMax(f64) })) |hit_record| {
                // TODO: consider zero
                var attenuation: linear.Color3 = undefined;
                const might_scattered = hit_record.mat.scatter(rand, _ray, hit_record, &attenuation);
                if (might_scattered) |scattered| {
                    return camera.ray_color(rand, depth - 1, scattered, hittable).mul(attenuation);
                }
                return black;
            }

            const unit_direction = _ray.dir.unit();
            const a = 0.5 * (unit_direction.y() + 1.0);

            return white.scale(1.0 - a).add(blue.scale(a));
        }

        fn sample_square(rand: std.Random) linear.Vec3 {
            // Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
            return linear.Vec3.initN(rand.float(f64) - 0.5, rand.float(f64) - 0.5, 0);
        }

        fn sample_defocus_disk(camera: Self, rand: std.Random) linear.Vec3 {
            // Returns a random point in the camera defocus disk.
            const p = linear.random_in_unit_disk(rand);
            return camera.center.add(camera.defocus_disk_u.scale(p.e[0])).add(camera.defocus_disk_v.scale(p.e[1]));
        }
    };
}

inline fn linear_to_gamma(color: linear.Color3) linear.Color3 {
    return linear.Color3.initN(
        if (color.e[0] > 0) @sqrt(color.e[0]) else 0,
        if (color.e[1] > 0) @sqrt(color.e[1]) else 0,
        if (color.e[2] > 0) @sqrt(color.e[2]) else 0,
    );
}

inline fn set_color(data: []u8, pixel_color: linear.Color3, i: usize, j: usize, comptime image_width: usize, comptime num_components: u8) void {
    const color_gamma_corrected = linear_to_gamma(pixel_color);
    const r = color_gamma_corrected.x();
    const g = color_gamma_corrected.y();
    const b = color_gamma_corrected.z();

    const rb: u8 = @intFromFloat(256 * ray.Interval.intensity.clamp(r));
    const gb: u8 = @intFromFloat(256 * ray.Interval.intensity.clamp(g));
    const bb: u8 = @intFromFloat(256 * ray.Interval.intensity.clamp(b));

    data[(i * image_width + j) * num_components] = rb;
    data[(i * image_width + j) * num_components + 1] = gb;
    data[(i * image_width + j) * num_components + 2] = bb;
}
