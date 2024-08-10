const std = @import("std");

pub fn build(b: *std.Build) void {
    // Define
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Construct exe
    const exe = b.addExecutable(.{
        .name = "zig-vulkan-triangle",
        .root_source_file = b.path("main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const vkzig_dep = b.dependency("vulkan_zig", .{
        .registry = @as([]const u8, b.pathFromRoot("C://Vulkan//1.3.290.0//share//vulkan//registry//vk.xml")),
    });
    const vkzig_bindings = vkzig_dep.module("vulkan-zig");
    exe.addModule("vulkan", vkzig_bindings);

    // Install Artifact
    b.installArtifact(exe);

    // Addictional run command
    const run_exe = b.addRunArtifact(exe);

    run_exe.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_exe.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_exe.step);
}
