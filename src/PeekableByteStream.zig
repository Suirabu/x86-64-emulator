const std = @import("std");
const mem = std.mem;

const Self = @This();

bytes: []const u8,
cursor: usize,

pub fn from(bytes: []const u8) Self {
    return Self{
        .bytes = bytes,
        .cursor = 0,
    };
}

pub fn read(self: *Self, buffer: []u8) !void {
    try self.peek(buffer);
    self.cursor += buffer.len;
}

pub fn peek(self: Self, buffer: []u8) !void {
    if (self.cursor + buffer.len >= self.bytes.len) {
        return error.EndOfStream;
    }
    @memcpy(buffer, self.bytes[self.cursor .. self.cursor + buffer.len]);
}

pub fn readByte(self: *Self) !u8 {
    var buffer: [1]u8 = undefined;
    try self.read(&buffer);
    return buffer[0];
}

pub fn peekByte(self: Self) !u8 {
    var buffer: [1]u8 = undefined;
    try self.peek(&buffer);
    return buffer[0];
}

pub fn readInt(self: *Self, comptime T: type) !T {
    var buffer: [@sizeOf(T)]u8 = undefined;
    try self.read(&buffer);
    // assume native-endian
    return mem.readIntNative(T, &buffer);
}

pub fn peekInt(self: *Self, comptime T: type) !T {
    var buffer: [@sizeOf(T)]u8 = undefined;
    try self.peek(&buffer);
    // assume native-endian
    return mem.readIntNative(T, buffer);
}
