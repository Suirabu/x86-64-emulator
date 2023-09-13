const std = @import("std");
const elf = std.elf;
const mem = std.mem;
const os = std.os;

const x86 = @import("x86.zig");
const Instruction = x86.Instruction;

pub const Cpu = struct {
    const Self = @This();

    memory: []const u8,
    ip: usize,
    registers: [16]u64,
    flags: Flags,

    is_running: bool,
    exit_code: u8,

    pub fn init(memory: usize, allocator: mem.Allocator) !Self {
        return Self{
            .memory = try allocator.alloc(u8, memory),
            .ip = undefined,
            .registers = undefined,
            .flags = undefined,
            .is_running = true,
            .exit_code = undefined,
        };
    }

    pub fn deinit(self: Self, allocator: mem.Allocator) void {
        allocator.free(self.memory);
    }

    pub fn loadElfExecutable(self: *Self, source: []const u8) !void {
        // parse ELF header
        var parse_source = std.io.fixedBufferStream(source);
        var ehdr = try elf.Header.read(&parse_source);

        // compute base address
        var phdr_iter = ehdr.program_header_iterator(&parse_source);
        var base_address: u64 = undefined;
        while (try phdr_iter.next()) |phdr| {
            if (phdr.p_type == elf.PT_LOAD) {
                base_address = phdr.p_vaddr - phdr.p_offset;
                break;
            }
        }

        @memcpy(@constCast(self.memory[base_address .. base_address + source.len]), source);
        self.ip = ehdr.entry;
    }

    pub fn run(self: *Self) !void {
        while (self.is_running) {
            try self.tick();
        }
    }

    pub fn tick(self: *Self) !void {
        const instruction = try Instruction.fromBytes(self.memory[self.ip..]);

        switch (instruction.primary_opcode) {
            // must have secondary opcode
            0x0F => switch (instruction.secondary_opcode) {
                // syscall
                0x05 => try self.syscall(),
                0x8C => if (!self.flags.zero and self.flags.carry) {
                    self.ip += instruction.source.immediate;
                },
                else => unreachable,
            },
            // cmp
            0x83 => {
                self.flags.carry = false;
                self.flags.zero = false;
                var dest_value = self.registers[instruction.register];
                var src_value = switch (instruction.source) {
                    .register => |register_index| self.registers[register_index],
                    else => instruction.source.asInt(),
                };
                if (dest_value == src_value) {
                    self.flags.zero = true;
                }
                if (dest_value < src_value) {
                    self.flags.carry = true;
                }
            },
            // mov reg, [base]
            0x8B => {
                self.registers[instruction.register] = switch (instruction.source) {
                    .register => |register_index| self.registers[register_index],
                    else => unreachable,
                };
            },
            // mov reg, immediate
            0xB8 => self.registers[instruction.register] = instruction.source.immediate,
            else => unreachable,
        }

        self.ip += instruction.length;
    }

    pub fn syscall(self: *Self) !void {
        const rax = self.registers[0];
        switch (rax) {
            0x01 => {
                const fd: os.system.fd_t = @intCast(self.registers[7]);
                const buffer_offset = self.registers[6];
                const length = self.registers[2];

                const buffer = self.memory[buffer_offset .. buffer_offset + length];

                // move result into rax
                self.registers[0] = try os.write(fd, buffer);
            },
            0x3C => {
                self.is_running = false;
                self.exit_code = @truncate(self.registers[7]); // rdi
            },
            else => {
                std.log.err("syscall {d} unimplemented", .{rax});
                return error.UnimplementedSyscall;
            },
        }
    }
};

const Flags = packed struct(u32) {
    carry: bool,
    _0: u1, // padding
    parity: bool,
    _1: u1, // padding
    auxiliary_carry: bool,
    _2: u1, // padding
    zero: bool,
    _3: u25,
};
