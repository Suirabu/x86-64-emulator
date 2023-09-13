const std = @import("std");
const PeekableByteStream = @import("PeekableByteStream.zig");

pub const Instruction = struct {
    prefixes: []const u8,
    primary_opcode: u8,
    secondary_opcode: u8,

    register: u4,
    source: Source,
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
                instruction.source = Source{ .immediate = try bs.readInt(u64) };
            } else {
                instruction.source = Source{ .immediate = try bs.readInt(u32) };
            }
        } else switch (try bs.peekByte()) {
            0x0F => {
                instruction.primary_opcode = try bs.readByte();

                switch (try bs.peekByte()) {
                    // syscall
                    0x05 => instruction.secondary_opcode = try bs.readByte(),
                    // jl/jnge
                    0x8c => {
                        instruction.secondary_opcode = try bs.readByte();
                        instruction.source = Source{ .immediate = try bs.readInt(u32) };
                    },
                    else => return opcodeUnimplemented(try bs.readByte()),
                }
            },
            // mov reg, [base]
            0x8B => {
                instruction.primary_opcode = try bs.readByte();
                // ModR/M byte
                const mod_rm_byte = try bs.readByte();
                instruction.register = @truncate((mod_rm_byte & 0x38) >> 3);
                // SIB
                if (mod_rm_byte & 0xC0 == 0x00 and mod_rm_byte & 0x07 == 0x04) {
                    const sib_byte = try bs.readByte();
                    switch (sib_byte & 0x3F) {
                        // [base]
                        0x24 => instruction.source = getSIBSource(sib_byte),
                        else => unreachable,
                    }
                }
            },
            // cmp
            0x83 => {
                instruction.primary_opcode = try bs.readByte();
                // ModR/M byte
                const mod_rm_byte = try bs.readByte();
                instruction.register = @truncate((mod_rm_byte & 0x38) >> 3);
                if (mod_rm_byte & 0xC0 == 0xC0) {
                    instruction.register = @truncate(mod_rm_byte & 0x07);
                }
                instruction.source = Source{ .immediate = try bs.readByte() };
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

    fn getSIBSource(sib_byte: u8) Source {
        return switch (sib_byte & 0x3F) {
            // [base]
            0x24 => Source{ .register = @truncate(sib_byte & 0x07) },
            else => unreachable,
        };
    }

    // needs to return `Instruction` to be used in `Instruction.fromBytes()`
    fn opcodeUnimplemented(opcode: u8) !Instruction {
        std.log.err("opcode {x} is currently unimplemented", .{opcode});
        return error.UnimplementedOpcode;
    }
};

const Source = union(enum) {
    register: u4,
    address: u64,
    immediate: u64,

    pub fn asInt(self: Source) u64 {
        return switch (self) {
            .address => |val| val,
            .immediate => |val| val,
            .register => unreachable,
        };
    }
};
