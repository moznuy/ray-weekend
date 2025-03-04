const std = @import("std");
const linear = @import("linear.zig");
const ray = @import("ray.zig");

pub const MaterialTag = enum {
    lambertian,
    metal,
    dielectric,
};

pub const Material = union(MaterialTag) {
    lambertian: struct {
        albedo: linear.Color3,
    },
    metal: struct {
        albedo: linear.Color3,
        fuzz: f64,
    },
    dielectric: struct {
        refraction_index: f64,
    },

    const Self = @This();

    // Todo: think about how to pass "attenuation" around
    pub fn scatter(self: Self, rand: std.Random, ray_in: ray.Ray3, hit_record: ray.HitRecord, attenuation: *linear.Color3) ?ray.Ray3 {
        // _ = ray_in;
        // _ = hit_record;
        // _ = attenuation;
        switch (self) {
            .lambertian => |lambertian| {
                var scatter_direction = hit_record.normal.add(linear.Vec3.random_unit_vector(rand));
                // Catch degenerate scatter direction
                if (scatter_direction.near_zero()) {
                    scatter_direction = hit_record.normal;
                }
                const scattered = ray.Ray3{ .orig = hit_record.p, .dir = scatter_direction };
                attenuation.* = lambertian.albedo;
                return scattered;
            },
            .metal => |metal| {
                const reflected_base = ray_in.dir.reflect(hit_record.normal);
                const reflected = reflected_base.unit().add(linear.Vec3.random_unit_vector(rand).scale(metal.fuzz));
                const scattered = ray.Ray3{ .orig = hit_record.p, .dir = reflected };
                attenuation.* = metal.albedo;
                if (scattered.dir.dot(hit_record.normal) > 0) {
                    return scattered;
                }
                return null;
            },
            .dielectric => |dielectric| {
                attenuation.* = linear.Color3.initN(1, 1, 1);
                const ri = if (hit_record.front_face) 1.0 / dielectric.refraction_index else dielectric.refraction_index;

                const ray_in_unit = ray_in.dir.unit();
                const refracted = ray_in_unit.refract(hit_record.normal, ri);

                const scattered = ray.Ray3{ .orig = hit_record.p, .dir = refracted };
                return scattered;
            },
        }

        return null;
    }
};
