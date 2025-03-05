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
                var scatter_direction = hit_record.normal.add(linear.random_unit_vector(rand));
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
                const reflected = reflected_base.unit().add(linear.random_unit_vector(rand).scale(metal.fuzz));
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
                const cos_theta = @min(ray_in_unit.negate().dot(hit_record.normal), 1.0);
                const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);

                const cannot_refract = ri * sin_theta > 1.0;

                const direction = blk: {
                    if (cannot_refract or reflectance(cos_theta, ri) > rand.float(f64)) {
                        break :blk ray_in_unit.reflect(hit_record.normal);
                    } else {
                        break :blk ray_in_unit.refract(hit_record.normal, ri);
                    }
                };
                const scattered = ray.Ray3{ .orig = hit_record.p, .dir = direction };
                return scattered;
            },
        }

        return null;
    }
};

fn reflectance(cosine: f64, refraction_index: f64) f64 {
    // Use Schlick's approximation for reflectance.
    const r0 = (1 - refraction_index) / (1 + refraction_index);
    const r0_squared = r0 * r0;
    return r0_squared + (1 - r0_squared) * std.math.pow(f64, 1 - cosine, 5);
}
