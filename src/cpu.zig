const std = @import("std");
const elf = std.elf;
const mem = std.mem;

const x86 = @import("x86.zig");
const Instruction = x86.Instruction;

pub const Cpu = struct {
    const Self = @This();

    memory: []const u8,
    ip: usize,
    registers: [16]u64,

    is_running: bool,
    exit_code: u8,

    pub fn init(memory: usize, allocator: mem.Allocator) !Self {
        return Self{
            .memory = try allocator.alloc(u8, memory),
            .ip = undefined,
            .registers = undefined,
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

        if (instruction.prefix) |_| {
            switch (instruction.primary_opcode) {
                // syscall
                0x05 => try self.syscall(),
                else => unreachable,
            }
        } else {
            switch (instruction.primary_opcode) {
                0xB8 => self.registers[instruction.register] = instruction.immediate,
                else => unreachable,
            }
        }

        self.ip += instruction.length;
    }

    pub fn syscall(self: *Self) !void {
        const rax = self.registers[0];
        switch (rax) {
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
