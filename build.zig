const std = @import("std");

pub fn build(b: *std.build.Builder) !void {
    const lib = b.addSharedLibrary("galdr", "src/main.zig", .unversioned);

    lib.setBuildMode(.ReleaseSmall);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;
    lib.strip = true;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    lib.install();

    const prefix = b.getInstallPath(.lib, "");
    const opt = b.addSystemCommand(&[_][]const u8{
        "wasm-opt",
        "-Oz",
        "--strip-debug",
        "--strip-producers",
        "--zero-filled-memory",
    });

    opt.addArtifactArg(lib);
    const optout = try std.fs.path.join(b.allocator, &.{ prefix, "galdr-opt.wasm" });
    defer b.allocator.free(optout);
    opt.addArgs(&.{ "--output", optout });

    const opt_step = b.step("opt", "Run wasm-opt on cart.wasm, producing opt.wasm");
    opt_step.dependOn(&lib.step);
    opt_step.dependOn(&opt.step);
}
