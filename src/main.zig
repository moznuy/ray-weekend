const std = @import("std");
const zstbi = @import("zstbi");

pub const Vec3 = struct {
    e: [3]f64 = [_]f64{ 0, 0, 0 },

    const Self = @This();

    pub inline fn initA(fields: [3]f64) Self {
        return .{ .e = fields };
    }

    pub inline fn initN(_x: f64, _y: f64, _z: f64) Self {
        return .{ .e = .{ _x, _y, _z } };
    }

    pub inline fn x(self: Self) f64 {
        return self.e[0];
    }
    pub inline fn y(self: Self) f64 {
        return self.e[1];
    }
    pub inline fn z(self: Self) f64 {
        return self.e[2];
    }

    pub fn accumulate(self: *Self, other: Self) void {
        self.e[0] += other.e[0];
        self.e[1] += other.e[1];
        self.e[2] += other.e[2];
    }

    pub fn negate(self: Self) Self {
        return .{ .e = [_]f64{
            -self.e[0],
            -self.e[1],
            -self.e[2],
        } };
    }

    pub fn scale(self: Self, scalar: f64) Self {
        return .{ .e = [_]f64{
            self.e[0] * scalar,
            self.e[1] * scalar,
            self.e[2] * scalar,
        } };
    }

    pub fn length(self: Self) f64 {
        return @sqrt(self.length_squred());
    }

    pub fn length_squred(self: Self) f64 {
        return self.e[0] * self.e[0] + self.e[1] * self.e[1] + self.e[2] * self.e[2];
    }

    pub fn add(self: Self, other: Self) Self {
        return .{ .e = [_]f64{
            self.e[0] + other.e[0],
            self.e[1] + other.e[1],
            self.e[2] + other.e[2],
        } };
    }

    pub fn sub(self: Self, other: Self) Self {
        return .{ .e = [_]f64{
            self.e[0] - other.e[0],
            self.e[1] - other.e[1],
            self.e[2] - other.e[2],
        } };
    }

    pub fn mul(self: Self, other: Self) Self {
        return .{ .e = [_]f64{
            self.e[0] * other.e[0],
            self.e[1] * other.e[1],
            self.e[2] * other.e[2],
        } };
    }

    pub fn dot(self: Self, other: Self) f64 {
        return self.e[0] * other.e[0] + self.e[1] * other.e[1] + self.e[2] * other.e[2];
    }

    pub fn cross(self: Self, other: Self) Self {
        return .{ .e = [_]f64{
            self.e[1] * other.e[2] - self.e[2] * other.e[1],
            self.e[2] * other.e[0] - self.e[0] * other.e[2],
            self.e[0] * other.e[1] - self.e[1] * other.e[0],
        } };
    }

    pub fn unit(self: Self) Self {
        return self.scale(1 / self.length());
    }

    pub fn random(rand: std.Random) Self {
        return .{ .e = [_]f64{
            rand.float(f64),
            rand.float(f64),
            rand.float(f64),
        } };
    }

    pub fn random_range(rand: std.Random, min: f64, max: f64) Self {
        return .{ .e = [_]f64{
            random_double_range(rand, min, max),
            random_double_range(rand, min, max),
            random_double_range(rand, min, max),
        } };
    }

    pub fn random_unit_vector(rand: std.Random) Self {
        while (true) {
            const p = Self.random_range(rand, -1, 1);
            const lensq = p.length_squred();
            if (1e-160 < lensq and lensq <= 1) {
                return p.scale(1 / @sqrt(lensq));
            }
        }
    }

    pub fn random_on_hemisphere(rand: std.Random, normal: Self) Self {
        const on_unit_sphere = Self.random_unit_vector(rand);
        if (on_unit_sphere.dot(normal) > 0.0) {
            return on_unit_sphere;
        } else {
            return on_unit_sphere.negate();
        }
    }
};

pub const Point3 = Vec3;
pub const Color3 = Vec3;
const white = Color3.initN(1, 1, 1);
const blue = Color3.initN(0.5, 0.7, 1);

pub const Ray3 = struct {
    orig: Point3,
    dir: Vec3,

    const Self = @This();

    pub fn at(self: Self, t: f64) Point3 {
        return self.orig.add(self.dir.scale(t));
    }
};

pub const Interval = struct {
    min: f64,
    max: f64,

    const empty = Interval{ .min = std.math.inf(f64), .max = -std.math.inf(f64) };
    const universe = Interval{ .min = -std.math.inf(f64), .max = std.math.inf(f64) };
    const intensity = Interval{ .min = 0, .max = 0.999 };
    const Self = @This();

    pub fn size(self: Self) f64 {
        return self.max - self.min;
    }

    pub fn contains(self: Self, x: f64) bool {
        return self.min <= x and x <= self.max;
    }

    pub fn surrounds(self: Self, x: f64) bool {
        return self.min < x and x < self.max;
    }

    pub fn clamp(self: Self, x: f64) f64 {
        if (x < self.min) return self.min;
        if (x > self.max) return self.max;
        return x;
    }
};

pub const HitRecord = struct {
    p: Point3,
    normal: Vec3,
    t: f64,
    front_face: bool,
};

pub const HittableTag = enum {
    sphere,
    many,
};

pub const Hittable = union(HittableTag) {
    sphere: struct {
        center: Point3,
        radius: f64, // todo: fmax(0, r) for setter?
    },
    many: std.ArrayList(Hittable),

    const Self = @This();

    pub fn hit(self: Self, ray: Ray3, ray_t: Interval) ?HitRecord {
        switch (self) {
            .sphere => |sphere| {
                const oc = sphere.center.sub(ray.orig);
                const a = ray.dir.length_squred();
                const h = ray.dir.dot(oc);
                const c = oc.length_squred() - sphere.radius * sphere.radius;

                const discriminant = h * h - a * c;
                if (discriminant < 0) {
                    return null;
                }

                const sqrtd = @sqrt(discriminant);
                // Find the nearest root that lies in the acceptable range.
                var root = (h - sqrtd) / a;
                if (!ray_t.surrounds(root)) {
                    root = (h + sqrtd) / a;
                    if (!ray_t.surrounds(root)) {
                        return null;
                    }
                }

                const t = root;
                const p = ray.at(root);
                const outward_normal = p.sub(sphere.center).scale(1 / sphere.radius);
                const front_face = ray.dir.dot(outward_normal) < 0;
                const normal = if (front_face) outward_normal else outward_normal.negate();

                return .{
                    .t = t,
                    .p = p,
                    .normal = normal,
                    .front_face = front_face,
                };
            },
            .many => |hittables| {
                var result_hit: ?HitRecord = null;
                // var hit_anything = false;
                var closest_so_far = ray_t.max;

                for (hittables.items) |hittable| {
                    if (hittable.hit(ray, Interval{ .min = ray_t.min, .max = closest_so_far })) |tmp_hit| {
                        // hit_anything = true;
                        closest_so_far = tmp_hit.t;
                        result_hit = tmp_hit;
                    }
                }

                return result_hit;
            },
        }
    }
};

pub fn Camera(_image_width: comptime_int, aspect_ration: comptime_float, _num_components: comptime_int, samples_per_pixel: comptime_int) type {
    const image_height_tmp: comptime_int = @intFromFloat(@as(comptime_float, @floatFromInt(_image_width)) / aspect_ration);
    const pixel_samples_scale: comptime_float = 1.0 / @as(comptime_float, @floatFromInt(samples_per_pixel));
    const max_depth: comptime_int = 50;

    return struct {
        center: Point3,
        pixel00_loc: Point3,
        pixel_delta_u: Vec3,
        pixel_delta_v: Vec3,
        rand: std.Random,

        const image_height: comptime_int = if (image_height_tmp < 0) 1 else image_height_tmp;
        const image_width: comptime_int = _image_width;
        const num_components: comptime_int = _num_components;
        const bytes_per_component: comptime_int = @sizeOf(u8);

        const Self = @This();

        pub fn render(camera: Self, rand: std.Random, world: Hittable, data: []u8) void {
            for (0..image_height) |i| {
                std.debug.print("\rScanlines remaining: {d:04}", .{image_height - i});
                for (0..image_width) |j| {
                    var pixel_color = Color3.initN(0, 0, 0);
                    inline for (0..samples_per_pixel) |_| {
                        const ray = camera.get_ray(i, j);
                        pixel_color.accumulate(ray_color(rand, max_depth, ray, world));
                    }

                    set_color(data, pixel_color.scale(pixel_samples_scale), i, j, image_width, num_components);
                }
            }
        }

        pub fn init(rand: std.Random) Self {
            const focal_length: comptime_float = 1.0;
            const viewport_height: comptime_float = 2.0;
            const viewport_width: comptime_float = viewport_height * (@as(comptime_float, @floatFromInt(image_width)) / @as(comptime_float, @floatFromInt(image_height)));

            const viewport_u = Vec3.initN(viewport_width, 0, 0);
            const viewport_v = Vec3.initN(0, -viewport_height, 0);

            const pixel_delta_u = viewport_u.scale(1.0 / @as(f64, @floatFromInt(image_width)));
            const pixel_delta_v = viewport_v.scale(1.0 / @as(f64, @floatFromInt(image_height)));

            const center = Point3.initN(0, 0, 0);
            const viewport_upper_left = center
                .sub(Vec3.initN(0, 0, focal_length))
                .sub(viewport_u.scale(0.5))
                .sub(viewport_v.scale(0.5));
            const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5));

            const camera = Self{
                .center = center,
                .pixel00_loc = pixel00_loc,
                .pixel_delta_u = pixel_delta_u,
                .pixel_delta_v = pixel_delta_v,
                .rand = rand,
            };
            return camera;
        }

        pub fn get_ray(camera: Self, i: usize, j: usize) Ray3 {
            const offset = sample_square(camera.rand);
            const pixel_sample = camera.pixel00_loc
                .add(camera.pixel_delta_u.scale(@as(f64, @floatFromInt(j)) + offset.x()))
                .add(camera.pixel_delta_v.scale(@as(f64, @floatFromInt(i)) + offset.y()));
            const ray_origin = camera.center;
            const ray_direction = pixel_sample.sub(ray_origin);

            return .{ .orig = ray_origin, .dir = ray_direction };
        }

        pub fn ray_color(rand: std.Random, depth: u64, ray: Ray3, hittable: Hittable) Color3 {
            // If we've exceeded the ray bounce limit, no more light is gathered.
            if (depth <= 0)
                return Color3.initN(0, 0, 0);

            if (hittable.hit(ray, Interval{ .min = 0.001, .max = std.math.floatMax(f64) })) |hit_record| {
                // const direction = Vec3.random_on_hemisphere(rand, hit_record.normal);
                // Lambertian reflect distribution:
                const direction = hit_record.normal.add(Vec3.random_unit_vector(rand));
                const new_ray = Ray3{ .orig = hit_record.p, .dir = direction };
                return ray_color(rand, depth - 1, new_ray, hittable).scale(0.5);
                // return hit_record.normal.add(white).scale(0.5);
            }

            const unit_direction = ray.dir.unit();
            const a = 0.5 * (unit_direction.y() + 1.0);

            return white.scale(1.0 - a).add(blue.scale(a));
        }
    };
}

pub inline fn random_double_range(rand: std.Random, min: f64, max: f64) f64 {
    // Returns a random real in [min,max).
    return min + (max - min) * rand.float(f64);
}

pub fn sample_square(rand: std.Random) Vec3 {
    // Returns the vector to a random point in the [-.5,-.5]-[+.5,+.5] unit square.
    return Vec3.initN(rand.float(f64) - 0.5, rand.float(f64) - 0.5, 0);
}

pub inline fn set_color(data: []u8, color: Color3, i: usize, j: usize, comptime image_width: usize, comptime num_components: u8) void {
    const r = color.x();
    const g = color.y();
    const b = color.z();

    const rb: u8 = @intFromFloat(256 * Interval.intensity.clamp(r));
    const gb: u8 = @intFromFloat(256 * Interval.intensity.clamp(g));
    const bb: u8 = @intFromFloat(256 * Interval.intensity.clamp(b));

    data[(i * image_width + j) * num_components] = rb;
    data[(i * image_width + j) * num_components + 1] = gb;
    data[(i * image_width + j) * num_components + 2] = bb;
}

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

    //World
    const _hittables = try std.ArrayList(Hittable).initCapacity(gpa.allocator(), 2);
    defer _hittables.deinit();
    var world = Hittable{ .many = _hittables };
    world.many.appendAssumeCapacity(.{ .sphere = .{ .center = Point3.initN(0, 0, -1), .radius = 0.5 } });
    world.many.appendAssumeCapacity(.{ .sphere = .{ .center = Point3.initN(0, -100.5, -1), .radius = 100 } });

    // Random
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.milliTimestamp()));
    const rand = prng.random();

    // Camera
    const CameraType = Camera(image_width, aspect_ration, 3, samples_per_pixel);
    const camera = CameraType.init(rand);

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
