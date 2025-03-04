const std = @import("std");

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

inline fn random_double_range(rand: std.Random, min: f64, max: f64) f64 {
    // Returns a random real in [min,max).
    return min + (max - min) * rand.float(f64);
}

pub const Point3 = Vec3;
pub const Color3 = Vec3;
