const std = @import("std");
const linear = @import("linear.zig");
const ray = @import("ray.zig");

pub const MaterialTag = enum {
    lambertian,
    metal,
};

pub const Material = union(MaterialTag) {
    // Todo: ? struct {albedo: Color3}
    lambertian: linear.Color3,
    metal: linear.Color3,

    const Self = @This();

    // Todo: think about how to pass "attenuation" around
    pub fn scatter(self: Self, rand: std.Random, ray_in: ray.Ray3, hit_record: ray.HitRecord, attenuation: *linear.Color3) ?ray.Ray3 {
        // _ = ray_in;
        // _ = hit_record;
        // _ = attenuation;
        switch (self) {
            .lambertian => |albedo| {
                var scatter_direction = hit_record.normal.add(linear.Vec3.random_unit_vector(rand));
                // Catch degenerate scatter direction
                if (scatter_direction.near_zero()) {
                    scatter_direction = hit_record.normal;
                }
                const scattered = ray.Ray3{ .orig = hit_record.p, .dir = scatter_direction };
                attenuation.* = albedo;
                return scattered;
            },
            .metal => |albedo| {
                const reflected = ray_in.dir.reflect(hit_record.normal);
                const scattered = ray.Ray3{ .orig = hit_record.p, .dir = reflected };
                attenuation.* = albedo;
                return scattered;
            },
        }

        return null;
    }
};
