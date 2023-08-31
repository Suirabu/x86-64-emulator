const std = @import("std");

pub const Instruction = struct {
    prefix: ?u8 = null,
    primary_opcode: u8,
    register: u4 = 0,
    immediate: u32 = 0,
    length: u8,

    pub fn fromBytes(bytes: []const u8) !Instruction {
        var fbs = std.io.fixedBufferStream(bytes);
        var reader = fbs.reader();

        var byte = try reader.readByte();

        // mov immediate word/dword
        if (byte & 0xF8 == 0xB8) {
            return Instruction{
                .primary_opcode = byte & 0xF8,
                .register = @truncate(byte & 0x07),
                .immediate = try reader.readIntNative(u32),
                .length = 5,
            };
        }

        // prefix byte
        if (byte == 0x0F) {
            byte = try reader.readByte();
            if (byte == 0x05) {
                return Instruction{
                    .prefix = 0x0F,
                    .primary_opcode = byte,
                    .length = 2,
                };
            }

            std.log.err("opcode 0F {X} is currently unimplemented", .{byte});
        }

        std.log.err("opcode {X} is currently unimplemented", .{byte});
        return error.UnimplementedOpcode;
    }
};
