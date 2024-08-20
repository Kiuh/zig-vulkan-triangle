const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("zglfw");
const GraphicsContext = @import("graphics_context.zig").GraphicsContext;

const Allocator = std.mem.Allocator;

const App = struct {
    // Std
    allocator: Allocator = undefined,

    // Vulkan
    gc: GraphicsContext = undefined,

    // Glfw
    window: *glfw.Window = undefined,

    // App
    size: @Vector(2, i32),
    app_name: [:0]const u8,

    pub fn init(allocator: Allocator, size: @Vector(2, i32), app_name: [:0]const u8) App {
        return App{
            .allocator = allocator,
            .size = size,
            .app_name = app_name,
        };
    }

    pub fn run(self: *App) !void {
        try self.initWindow();
        try self.initVulkan();
        try self.mainLoop();
    }

    pub fn initWindow(self: *App) !void {
        try glfw.init();
        self.window = try glfw.Window.create(self.size[0], self.size[1], self.app_name, null);
    }

    pub fn initVulkan(self: *App) !void {
        self.gc = try GraphicsContext.init(self.allocator, self.app_name, self.window);
        std.log.debug("Using device: {s}", .{self.gc.deviceName()});
    }

    pub fn mainLoop(self: *App) !void {
        while (!self.window.shouldClose()) {
            glfw.pollEvents();
            self.window.swapBuffers();
        }
    }

    pub fn deinit(self: *App) void {
        self.gc.deinit();
        glfw.terminate();
        self.window.destroy();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var app = App.init(gpa.allocator(), .{ 1280, 720 }, "Zig_Vulkan_Glfw");
    // defer app.deinit();

    try app.run();
}
