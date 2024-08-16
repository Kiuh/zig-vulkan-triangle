const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("zglfw");

pub fn main() !void {
    try glfw.init();
    defer glfw.terminate();

    const window = try glfw.Window.create(600, 600, "Zig - vulkan", null);
    defer window.destroy();

    while (!window.shouldClose()) {
        glfw.pollEvents();
    }
}
