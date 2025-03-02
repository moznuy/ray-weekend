const std = @import("std");
const zstbi = @import("zstbi");

pub const Vec3 = struct {
    e: [3]f64 = [_]f64{ 0, 0, 0 },

    const Self = @This();

    pub fn init(fields: [3]f64) Self {
        return .{
            .e = fields,
        };
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

    pub fn scale(self: Self, scalar: anytype) Self {
        return .{ .e = [_]f64{ self.e[0] * scalar, -self.e[1] * scalar, -self.e[2] * scalar } };
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

pub const Point = Vec3;
pub const Color = Vec3;

pub inline fn set_color(data: []u8, color: Color, i: usize, j: usize, comptime image_width: usize, comptime num_components: u8) void {
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
    zstbi.init(gpa.allocator());
    defer zstbi.deinit();

    const image_width = 256;
    const image_height = 256;
    const num_components = 3;
    const bytes_per_component = @sizeOf(u8);

    var data: [image_width * image_height * num_components]u8 = undefined;
    @memset(&data, 0);

    for (0..image_height) |i| {
        std.debug.print("\rScanlines remaining: {d:04}", .{image_height - i});
        for (0..image_width) |j| {
            const color = Color.init(.{ @as(f64, @floatFromInt(j)) / (image_width - 1), @as(f64, @floatFromInt(i)) / (image_height - 1), 0 });
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
