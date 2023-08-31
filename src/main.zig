const std = @import("std");
const elf = std.elf;

const Cpu = @import("cpu.zig").Cpu;

pub fn main() !u8 {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    // read cmd args
    var args = try std.process.argsAlloc(gpa.allocator());
    defer std.process.argsFree(gpa.allocator(), args);

    if (args.len < 2) {
        return error.MissingFilePath;
    }

    const file_path = args[1];

    var file = try std.fs.cwd().openFile(file_path, .{});
    var file_content = try file.readToEndAlloc(gpa.allocator(), std.math.maxInt(u32));
    defer gpa.allocator().free(file_content);

    // initialize CPU with 16MiB of memory
    var cpu = try Cpu.init(0x1000000, gpa.allocator());
    defer cpu.deinit(gpa.allocator());

    try cpu.loadElfExecutable(file_content);
    try cpu.run();

    return cpu.exit_code;
}
