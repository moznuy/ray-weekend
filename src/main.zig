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
        return .{ .e = [_]f64{ -self.e[0], -self.e[1], -self.e[2] } };
    }

    pub fn scale(self: Self, scalar: f64) Self {
        return .{ .e = [_]f64{ self.e[0] * scalar, self.e[1] * scalar, self.e[2] * scalar } };
    }

    pub fn length(self: Self) f64 {
        return @sqrt(self.length_squred());
    }

    pub fn length_squred(self: Self) f64 {
        return self.e[0] * self.e[0] + self.e[1] * self.e[1] + self.e[2] * self.e[2];
    }

    pub fn add(self: Self, other: Self) Self {
        return .{ .e = [_]f64{ self.e[0] + other.e[0], self.e[1] + other.e[1], self.e[2] + other.e[2] } };
    }

    pub fn sub(self: Self, other: Self) Self {
        return .{ .e = [_]f64{ self.e[0] - other.e[0], self.e[1] - other.e[1], self.e[2] - other.e[2] } };
    }

    pub fn mul(self: Self, other: Self) Self {
        return .{ .e = [_]f64{ self.e[0] * other.e[0], self.e[1] * other.e[1], self.e[2] * other.e[2] } };
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

pub fn Camera(image_width: comptime_int, aspect_ration: comptime_float, num_components: comptime_int) type {
    const image_height_tmp: comptime_int = @intFromFloat(@as(comptime_float, @floatFromInt(image_width)) / aspect_ration);
    const image_height: comptime_int = if (image_height_tmp < 0) 1 else image_height_tmp;

    return struct {
        image_height: comptime_int = image_height,
        image_width: comptime_int = image_width,
        num_components: comptime_int = num_components,
        bytes_per_component: comptime_int = @sizeOf(u8),

        CameraType: type = struct {
            // aspect_ratio: comptime_float = undefined,
            // image_width: comptime_int = image_width,
            // image_height: comptime_int = image_height,
            center: Point3 = undefined,
            pixel00_loc: Point3 = undefined,
            pixel_delta_u: Vec3 = undefined,
            pixel_delta_v: Vec3 = undefined,

            // num_components: comptime_int = num_components,
            // bytes_per_component: comptime_int = @sizeOf(u8),

            const Self = @This();

            pub fn render(camera: Self, world: Hittable, data: []u8) void {
                for (0..image_height) |i| {
                    std.debug.print("\rScanlines remaining: {d:04}", .{image_height - i});
                    for (0..image_width) |j| {
                        // const color = Color3.initN(@as(f64, @floatFromInt(j)) / (image_width - 1), @as(f64, @floatFromInt(i)) / (image_height - 1), 0);
                        const pixel_center = camera.pixel00_loc.add(camera.pixel_delta_u.scale(@floatFromInt(j))).add(camera.pixel_delta_v.scale(@floatFromInt(i)));
                        const ray_direction = pixel_center.sub(camera.center);
                        const ray = Ray3{ .orig = camera.center, .dir = ray_direction };
                        const color = ray_color(ray, world);
                        set_color(data, color, i, j, image_width, num_components);
                    }
                }
            }

            pub fn init() Self {
                const focal_length: comptime_float = 1.0;
                const viewport_height: comptime_float = 2.0;
                const viewport_width: comptime_float = viewport_height * (@as(comptime_float, @floatFromInt(image_width)) / @as(comptime_float, @floatFromInt(image_height)));

                const viewport_u = Vec3.initN(viewport_width, 0, 0);
                const viewport_v = Vec3.initN(0, -viewport_height, 0);

                const pixel_delta_u = viewport_u.scale(1.0 / @as(f64, @floatFromInt(image_width)));
                const pixel_delta_v = viewport_v.scale(1.0 / @as(f64, @floatFromInt(image_height)));

                const center = Point3.initN(0, 0, 0);
                const viewport_upper_left = center.sub(Vec3.initN(0, 0, focal_length)).sub(viewport_u.scale(0.5)).sub(viewport_v.scale(0.5));
                const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5));

                const camera = Self{
                    // .aspect_ratio = aspect_ration,
                    // .image_width = image_width,
                    // .image_height = image_height,
                    .center = center,
                    .pixel00_loc = pixel00_loc,
                    .pixel_delta_u = pixel_delta_u,
                    .pixel_delta_v = pixel_delta_v,
                };
                return camera;
            }

            pub fn ray_color(ray: Ray3, hittable: Hittable) Color3 {
                if (hittable.hit(ray, Interval{ .min = 0, .max = std.math.floatMax(f64) })) |hit_record| {
                    return hit_record.normal.add(white).scale(0.5);
                }

                const unit_direction = ray.dir.unit();
                const a = 0.5 * (unit_direction.y() + 1.0);

                return white.scale(1.0 - a).add(blue.scale(a));
            }
        },
    };
}

pub inline fn set_color(data: []u8, color: Color3, i: usize, j: usize, comptime image_width: usize, comptime num_components: u8) void {
    const r = color.x();
    const g = color.y();
    const b = color.z();

    const rb: u8 = @intFromFloat(255.999 * r);
    const gb: u8 = @intFromFloat(255.999 * g);
    const bb: u8 = @intFromFloat(255.999 * b);

    data[(i * image_width + j) * num_components] = rb;
    data[(i * image_width + j) * num_components + 1] = gb;
    data[(i * image_width + j) * num_components + 2] = bb;
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.debug.print("Leak detected!", .{});
    }

    // Image
    const aspect_ration: comptime_float = 16.0 / 9.0;
    const image_width: comptime_int = 400;

    //World
    const _hittables = try std.ArrayList(Hittable).initCapacity(gpa.allocator(), 2);
    defer _hittables.deinit();
    var world = Hittable{ .many = _hittables };
    world.many.appendAssumeCapacity(.{ .sphere = .{ .center = Point3.initN(0, 0, -1), .radius = 0.5 } });
    world.many.appendAssumeCapacity(.{ .sphere = .{ .center = Point3.initN(0, -100.5, -1), .radius = 100 } });

    // Camera
    const CameraHelper = Camera(image_width, aspect_ration, 3){};
    const camera = CameraHelper.CameraType.init();

    // Data
    var data: [CameraHelper.image_width * CameraHelper.image_height * CameraHelper.num_components]u8 = undefined;
    @memset(&data, 0);

    camera.render(world, &data);

    zstbi.init(gpa.allocator());
    defer zstbi.deinit();
    const image: zstbi.Image = .{
        .data = &data,
        .width = image_width,
        .height = CameraHelper.image_height,
        .num_components = CameraHelper.num_components,
        .bytes_per_component = CameraHelper.bytes_per_component,
        .bytes_per_row = image_width * CameraHelper.num_components * CameraHelper.bytes_per_component,
        .is_hdr = false,
    };
    try image.writeToFile("image.png", .png);

    std.debug.print("\nDone.\n", .{});
}
