const std = @import("std");
const PeekableByteStream = @import("PeekableByteStream.zig");

pub const Instruction = struct {
    prefix: ?u8 = null,
    primary_opcode: u8,
    register: u4 = 0,
    immediate: u32 = 0,
    length: u8,

    pub fn fromBytes(bytes: []const u8) !Instruction {
        var bs = PeekableByteStream.from(bytes);

        // mov immediate word/dword
        if (try bs.peekByte() & 0xF8 == 0xB8) {
            const opcode_byte = try bs.readByte();

            return Instruction{
                .primary_opcode = opcode_byte & 0xF8,
                .register = @truncate(opcode_byte & 0x07),
                .immediate = try bs.readInt(u32),
                .length = 5,
            };
        }

        // prefix byte
        if (try bs.peekByte() == 0x0F) {
            _ = try bs.readByte();
            if (try bs.peekByte() == 0x05) {
                return Instruction{
                    .prefix = 0x0F,
                    .primary_opcode = try bs.readByte(),
                    .length = 2,
                };
            }

            std.log.err("opcode {X} is currently unimplemented", .{try bs.readByte()});
        }

        std.log.err("opcode {X} is currently unimplemented", .{try bs.readByte()});
        return error.UnimplementedOpcode;
    }
};
