const std = @import("std");

queue: std.ArrayList(usize),
mutex: std.Thread.Mutex,
cond: std.Thread.Condition,

const Self = @This();

pub fn init(allocator: std.mem.Allocator) Self {
    return .{
        .queue = std.ArrayList(usize).init(allocator),
        .mutex = std.Thread.Mutex{},
        .cond = std.Thread.Condition{},
    };
}

pub fn deinit(self: Self) void {
    // todo: what if someone wait?
    self.queue.deinit();
}

pub fn push(self: *Self, data: usize) !void {
    {
        self.mutex.lock();
        defer self.mutex.unlock();

        try self.queue.append(data);
    }
    self.cond.signal();
}

pub fn pop(self: *Self) usize {
    self.mutex.lock();
    defer self.mutex.unlock();

    while (self.queue.items.len == 0) {
        self.cond.wait(&self.mutex);
    }

    // TODO: replcace with deque where it's not O(N)
    // TODO: std.std.SinglyLinkedList?
    return self.queue.orderedRemove(0);
}

pub fn try_pop(self: *Self) ?usize {
    self.mutex.lock();
    defer self.mutex.unlock();

    if (self.queue.items.len == 0) return null;
    // TODO: replcace with deque where it's not O(N)
    // TODO: std.std.SinglyLinkedList?
    return self.queue.orderedRemove(0);
}
