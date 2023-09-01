const std = @import("std");
const PeekableByteStream = @import("PeekableByteStream.zig");

pub const Instruction = struct {
    primary_opcode: u8,
    secondary_opcode: u8 = undefined,

    register: u4 = undefined,
    immediate: u32 = undefined,
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
                    .primary_opcode = 0x0F,
                    .secondary_opcode = try bs.readByte(),
                    .length = 2,
                };
            }

            std.log.err("opcode {X} is currently unimplemented", .{try bs.readByte()});
        }

        std.log.err("opcode {X} is currently unimplemented", .{try bs.readByte()});
        return error.UnimplementedOpcode;
    }
};
