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

const Ray3 = struct {
    orig: Point3,
    dir: Vec3,

    const Self = @This();

    pub fn at(self: Self, t: f64) Point3 {
        return self.orig.add(self.dir.scale(t));
    }
};

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

pub fn hit_sphere(center: Point3, radius: f64, ray: Ray3) f64 {
    const oc = center.sub(ray.orig);
    const a = ray.dir.length_squred();
    const h = ray.dir.dot(oc);
    const c = oc.length_squred() - radius * radius;
    const discriminant = h * h - a * c;

    if (discriminant < 0) {
        return -1.0;
    } else {
        return (h - @sqrt(discriminant)) / a;
    }
}

pub fn ray_color(ray: Ray3) Color3 {
    const white = Color3.initN(1, 1, 1);
    const blue = Color3.initN(0.5, 0.7, 1);
    // const red = Color3.initN(1, 0, 0);
    const sphre_center = Point3.initN(0, 0, -1);

    const t = hit_sphere(sphre_center, 0.5, ray);
    if (t > 0.0) {
        const n = ray.at(t).sub(sphre_center).unit();
        return Color3.initN(n.x() + 1, n.y() + 1, n.z() + 1).scale(0.5);
    }

    const unit_direction = ray.dir.unit();
    const a = 0.5 * (unit_direction.y() + 1.0);

    return white.scale(1.0 - a).add(blue.scale(a));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const deinit_status = gpa.deinit();
        //fail test; can't try in defer as defer is executed after we return
        if (deinit_status == .leak) std.debug.print("Leak detected!", .{});
    }
    zstbi.init(gpa.allocator());
    defer zstbi.deinit();

    // Image
    const aspect_ration: comptime_float = 16.0 / 9.0;
    const image_width: comptime_int = 400;
    const image_height_tmp: comptime_int = @intFromFloat(@as(comptime_float, @floatFromInt(image_width)) / aspect_ration);
    const image_height: comptime_int = if (image_height_tmp < 0) 1 else image_height_tmp;

    // Camera
    const focal_length: comptime_float = 1.0;
    const viewport_height: comptime_float = 2.0;
    const viewport_width: comptime_float = viewport_height * (@as(comptime_float, @floatFromInt(image_width)) / @as(comptime_float, @floatFromInt(image_height)));
    const camera_center = Point3.initN(0, 0, 0);
    const viewport_u = Vec3.initN(viewport_width, 0, 0);
    const viewport_v = Vec3.initN(0, -viewport_height, 0);
    const pixel_delta_u = viewport_u.scale(1.0 / @as(f64, @floatFromInt(image_width)));
    const pixel_delta_v = viewport_v.scale(1.0 / @as(f64, @floatFromInt(image_height)));
    const viewport_upper_left = camera_center.sub(Vec3.initN(0, 0, focal_length)).sub(viewport_u.scale(0.5)).sub(viewport_v.scale(0.5));
    const pixel00_loc = viewport_upper_left.add(pixel_delta_u.add(pixel_delta_v).scale(0.5));

    // Data
    const num_components: comptime_int = 3;
    const bytes_per_component = @sizeOf(u8);
    var data: [image_width * image_height * num_components]u8 = undefined;
    @memset(&data, 0);

    for (0..image_height) |i| {
        std.debug.print("\rScanlines remaining: {d:04}", .{image_height - i});
        for (0..image_width) |j| {
            // const color = Color3.initN(@as(f64, @floatFromInt(j)) / (image_width - 1), @as(f64, @floatFromInt(i)) / (image_height - 1), 0);
            const pixel_center = pixel00_loc.add(pixel_delta_u.scale(@floatFromInt(j))).add(pixel_delta_v.scale(@floatFromInt(i)));
            const ray_direction = pixel_center.sub(camera_center);
            const color = ray_color(.{ .orig = camera_center, .dir = ray_direction });
            set_color(&data, color, i, j, image_width, num_components);
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
    try image.writeToFile("image.png", .png);

    std.debug.print("\nDone.\n", .{});
}
