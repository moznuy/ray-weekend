const std = @import("std");
const linear = @import("linear.zig");

pub const Interval = struct {
    min: f64,
    max: f64,

    pub const empty = Interval{ .min = std.math.inf(f64), .max = -std.math.inf(f64) };
    pub const universe = Interval{ .min = -std.math.inf(f64), .max = std.math.inf(f64) };
    pub const intensity = Interval{ .min = 0, .max = 0.999 };

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

pub const Ray3 = struct {
    orig: linear.Point3,
    dir: linear.Vec3,

    const Self = @This();

    pub fn at(self: Self, t: f64) linear.Point3 {
        return self.orig.add(self.dir.scale(t));
    }
};

pub const HitRecord = struct {
    p: linear.Point3,
    normal: linear.Vec3,
    t: f64,
    front_face: bool,
};

pub const HittableTag = enum {
    sphere,
    many,
};

pub const Hittable = union(HittableTag) {
    sphere: struct {
        center: linear.Point3,
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
