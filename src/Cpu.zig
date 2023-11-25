const std = @import("std");
const elf = std.elf;
const mem = std.mem;
const os = std.os;
const system = os.system;

const Instruction = @import("Instruction.zig");

const Cpu = @This();

// register indices
const rax = 0;
const rcx = 1;
const rdx = 2;
const rbx = 3;
const rsp = 4;
const rbp = 5;
const rsi = 6;
const rdi = 7;

memory: []const u8,
ip: usize,
registers: [16]u64,

is_running: bool,
exit_code: u8,

pub fn init(memory: usize, allocator: mem.Allocator) !Cpu {
    return Cpu{
        .memory = try allocator.alloc(u8, memory),
        .ip = undefined,
        .registers = undefined,
        .is_running = true,
        .exit_code = undefined,
    };
}

pub fn deinit(self: Cpu, allocator: mem.Allocator) void {
    allocator.free(self.memory);
}

pub fn loadElfExecutable(self: *Cpu, source: []const u8) !void {
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

pub fn run(self: *Cpu) !void {
    while (self.is_running) {
        try self.tick();
    }
}

pub fn tick(self: *Cpu) !void {
    const instruction = try Instruction.fromBytes(self.memory[self.ip..]);

    switch (instruction.primary_opcode) {
        // must have secondary opcode
        0x0F => switch (instruction.secondary_opcode) {
            // syscall
            0x05 => try self.syscall(),

            else => unreachable, // unimplemented instruction
        },

        // imul reg, byte
        0x6B => self.registers[instruction.register] *= instruction.immediate,

        // arithmetic
        0x83 => {
            switch (instruction.secondary_opcode) {
                // add
                0 => self.registers[instruction.register] += instruction.immediate,
                else => |arith_specififer| {
                    std.log.err("arithmetic operand specifier {d} unimplemented", .{arith_specififer});
                    return error.UnimplementedArithmeticOperation;
                },
            }
        },

        // mov immediate
        0xB8 => self.registers[instruction.register] = instruction.immediate,

        else => unreachable, // unimplemented instruction
    }

    self.ip += instruction.length;
}

pub fn syscall(self: *Cpu) !void {
    switch (self.registers[rax]) {
        // write
        0x01 => {
            const fd: system.fd_t = @intCast(self.registers[rdi]);
            const buffer_offset = self.registers[rsi];
            const length = self.registers[rdx];

            const buffer = self.memory[buffer_offset .. buffer_offset + length];
            self.registers[rax] = try os.write(fd, buffer);
        },

        // exit
        0x3C => {
            self.is_running = false;
            self.exit_code = @truncate(self.registers[rdi]);
        },

        // unimplemented
        else => |syscall_number| {
            std.log.err("syscall {d} unimplemented", .{syscall_number});
            return error.UnimplementedSyscall;
        },
    }
}
