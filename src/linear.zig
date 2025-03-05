const std = @import("std");

const VecType = @Vector(4, f64);

pub const Vec3 = struct {
    e: VecType,

    const Self = @This();

    pub inline fn initA(fields: [3]f64) Self {
        return .{ .e = .{ fields[0], fields[1], fields[2], 0 } };
    }

    pub inline fn initN(_x: f64, _y: f64, _z: f64) Self {
        return .{ .e = .{ _x, _y, _z, 0 } };
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
    pub inline fn w(self: Self) f64 {
        return self.e[3];
    }

    pub inline fn accumulate(self: *Self, other: Self) void {
        self.e += other.e;
    }

    pub inline fn negate(self: Self) Self {
        return .{ .e = -self.e };
    }

    pub inline fn scale(self: Self, scalar: f64) Self {
        return .{ .e = self.e * @as(VecType, @splat(scalar)) };
    }

    pub inline fn length(self: Self) f64 {
        return @sqrt(self.length_squred());
    }

    pub inline fn length_squred(self: Self) f64 {
        return @reduce(.Add, self.mul(self).e);
    }

    pub inline fn add(self: Self, other: Self) Self {
        return .{ .e = self.e + other.e };
    }

    pub inline fn sub(self: Self, other: Self) Self {
        return .{ .e = self.e - other.e };
    }

    pub inline fn mul(self: Self, other: Self) Self {
        return .{ .e = self.e * other.e };
    }

    pub inline fn dot(self: Self, other: Self) f64 {
        return @reduce(.Add, self.mul(other).e);
    }

    pub inline fn cross(self: Self, other: Self) Self {
        return .{ .e = [_]f64{
            self.e[1] * other.e[2] - self.e[2] * other.e[1],
            self.e[2] * other.e[0] - self.e[0] * other.e[2],
            self.e[0] * other.e[1] - self.e[1] * other.e[0],
            0,
        } };
    }

    pub inline fn reflect(self: Self, normal: Self) Self {
        return self.sub(normal.scale(2 * self.dot(normal)));
    }

    pub inline fn refract(self: Self, normal: Self, etai_over_etat: f64) Self {
        const cos_theta = @min(self.negate().dot(normal), 1.0);
        const ray_out_perp = self.add(normal.scale(cos_theta)).scale(etai_over_etat);
        // TODO: try 1-@abs(x) instead of @abs(1-x)
        const ray_out_parallel = normal.scale(-@sqrt(@abs(1 - ray_out_perp.length_squred())));
        return ray_out_perp.add(ray_out_parallel);
    }

    pub inline fn unit(self: Self) Self {
        return self.scale(1 / self.length());
    }

    pub inline fn near_zero(self: Self) bool {
        const s = 1e-8;
        return @abs(self.e[0]) < s and @abs(self.e[1]) < s and @abs(self.e[2]) < s;
    }
};

pub inline fn random_vec(rand: std.Random) Vec3 {
    return .{ .e = .{
        rand.float(f64),
        rand.float(f64),
        rand.float(f64),
        0,
    } };
}

pub inline fn random_vec_range(rand: std.Random, min: f64, max: f64) Vec3 {
    return .{ .e = .{
        random_double_range(rand, min, max),
        random_double_range(rand, min, max),
        random_double_range(rand, min, max),
        0,
    } };
}

pub inline fn random_unit_vector(rand: std.Random) Vec3 {
    while (true) {
        const p = random_vec_range(rand, -1, 1);
        const lensq = p.length_squred();
        if (1e-160 < lensq and lensq <= 1) {
            return p.scale(1 / @sqrt(lensq));
        }
    }
}

pub inline fn random_on_hemisphere(rand: std.Random, normal: Vec3) Vec3 {
    const on_unit_sphere = random_unit_vector(rand);
    if (on_unit_sphere.dot(normal) > 0.0) {
        return on_unit_sphere;
    } else {
        return on_unit_sphere.negate();
    }
}

pub inline fn random_in_unit_disk(rand: std.Random) Vec3 {
    while (true) {
        const p = Vec3{ .e = .{
            random_double_range(rand, -1, 1),
            random_double_range(rand, -1, 1),
            0,
            0,
        } };

        if (p.length_squred() < 1) {
            return p;
        }
    }
}

inline fn random_double_range(rand: std.Random, min: f64, max: f64) f64 {
    // Returns a random real in [min,max).
    return min + (max - min) * rand.float(f64);
}

pub const Point3 = Vec3;
pub const Color3 = Vec3;
