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

    const description = "\"GALDR - a roguelike full of spells!\"";

    const bundle_html = b.addSystemCommand(&[_][]const u8{
        "w4",
        "bundle",
        "--description",
        description,
        "--title",
        "GALDR",
    });

    const htmlout = try std.fs.path.join(b.allocator, &.{ prefix, "galdr.html" });
    defer b.allocator.free(htmlout);
    bundle_html.addArgs(&.{ "--html", htmlout });
    bundle_html.addArgs(&.{optout});

    const bundle_linux = b.addSystemCommand(&[_][]const u8{
        "w4",
        "bundle",
        "--description",
        description,
        "--title",
        "GALDR",
    });

    const linuxout = try std.fs.path.join(b.allocator, &.{ prefix, "galdr.x86_64" });
    defer b.allocator.free(linuxout);
    bundle_linux.addArgs(&.{ "--linux", linuxout });
    bundle_linux.addArgs(&.{optout});

    const bundle_windows = b.addSystemCommand(&[_][]const u8{
        "w4",
        "bundle",
        "--description",
        description,
        "--title",
        "GALDR",
    });

    const windowsout = try std.fs.path.join(b.allocator, &.{ prefix, "galdr.exe" });
    defer b.allocator.free(windowsout);
    bundle_windows.addArgs(&.{ "--windows", windowsout });
    bundle_windows.addArgs(&.{optout});

    const bundle_step = b.step("bundle", "package galdr-opt.wasm to html/linux/windows");
    bundle_step.dependOn(&opt.step);
    bundle_step.dependOn(&bundle_html.step);
    bundle_step.dependOn(&bundle_linux.step);
    bundle_step.dependOn(&bundle_windows.step);
}
