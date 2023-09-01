const std = @import("std");
const PeekableByteStream = @import("PeekableByteStream.zig");

pub const Instruction = struct {
    prefixes: []const u8,
    primary_opcode: u8,
    secondary_opcode: u8 = undefined,

    register: u4 = undefined,
    immediate: u64 = undefined,
    length: usize,

    pub fn fromBytes(bytes: []const u8) !Instruction {
        var bs = PeekableByteStream.from(bytes);

        var instruction: Instruction = undefined;

        var wide_operand = false;

        // get prefixes
        while (isPrefix(try bs.peekByte())) {
            const prefix_byte = try bs.readByte();
            // REX prefix
            if (prefix_byte & 0xF0 == 0x40) {
                if (prefix_byte & 0x08 != 0) {
                    wide_operand = true;
                }
            }
        }

        const prefixes_len = bs.getPosition();
        instruction.prefixes = bytes[0..prefixes_len];

        // mov immediate word/dword
        if (try bs.peekByte() & 0xF8 == 0xB8) {
            const opcode_byte = try bs.readByte();
            instruction.primary_opcode = opcode_byte & 0xF8;
            instruction.register = @truncate(opcode_byte & 0x07);

            if (wide_operand) {
                instruction.immediate = try bs.readInt(u64);
            } else {
                instruction.immediate = try bs.readInt(u32);
            }
        } else switch (try bs.peekByte()) {
            0x0F => {
                instruction.primary_opcode = try bs.readByte();

                // syscall
                switch (try bs.peekByte()) {
                    0x05 => instruction.secondary_opcode = try bs.readByte(),
                    else => return opcodeUnimplemented(try bs.readByte()),
                }
            },
            else => return opcodeUnimplemented(try bs.readByte()),
        }

        instruction.length = bs.getPosition();
        return instruction;
    }

    fn isPrefix(byte: u8) bool {
        // REX prefix byte
        if (byte & 0xF0 == 0x40) {
            return true;
        }
        return false;
    }

    // needs to return `Instruction` to be used in `Instruction.fromBytes()`
    fn opcodeUnimplemented(opcode: u8) !Instruction {
        std.log.err("opcode {x} is currently unimplemented", .{opcode});
        return error.UnimplementedOpcode;
    }
};
