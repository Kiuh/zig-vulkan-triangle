const std = @import("std");
const vk = @import("vulkan");
const glfw = @import("glfw");

/// Default GLFW error handling callback
fn errorCallback(error_code: glfw.ErrorCode, description: [:0]const u8) void {
    std.log.err("glfw: {}: {s}\n", .{ error_code, description });
}

const BaseDispatch = vk.BaseWrapper(.{
    .createInstance = true,
    .enumerateInstanceExtensionProperties = true,
    .getInstanceProcAddr = true,
});

const InstanceDispatch = vk.InstanceWrapper(.{
    .destroyInstance = true,
    .createDevice = true,
    .destroySurfaceKHR = true,
    .enumeratePhysicalDevices = true,
    .getPhysicalDeviceProperties = true,
    .enumerateDeviceExtensionProperties = true,
    .getPhysicalDeviceSurfaceFormatsKHR = true,
    .getPhysicalDeviceSurfacePresentModesKHR = true,
    .getPhysicalDeviceSurfaceCapabilitiesKHR = true,
    .getPhysicalDeviceQueueFamilyProperties = true,
    .getPhysicalDeviceSurfaceSupportKHR = true,
    .getPhysicalDeviceMemoryProperties = true,
    .getDeviceProcAddr = true,
});

const Application = struct {
    const Self = @This();

    // General Info
    title: [*:0]const u8 = undefined,
    width: u32 = undefined,
    height: u32 = undefined,

    // Glfw stuff
    window: glfw.Window = undefined,

    //Vulkan variables
    vkb: BaseDispatch = undefined,
    vki: InstanceDispatch = undefined,
    instance: vk.Instance = undefined,

    pub fn init(_title: [*:0]const u8, _width: u32, _height: u32) Self {
        const self = Self{ .title = _title, .width = _width, .height = _height };
        return self;
    }

    pub fn run(self: *Self) !void {
        try self.initWindow();
        try self.initVulkan();
        try self.mainLoop();
    }

    fn initWindow(self: *Self) error{ FailedToInitializeGLFW, CannotCreateGLFWWindow }!void {
        // Init glfw
        glfw.setErrorCallback(errorCallback);
        if (!glfw.init(.{})) {
            std.log.err("Failed to initialize GLFW: {?s}", .{glfw.getErrorString()});
            return error.FailedToInitializeGLFW;
        }
        // Init window
        self.window = glfw.Window.create(self.width, self.height, self.title, null, null, .{
            .client_api = .no_api,
            .resizable = false,
        }) orelse {
            std.log.err("Failed to create GLFW window: {?s}", .{glfw.getErrorString()});
            return error.CannotCreateGLFWWindow;
        };
    }

    fn initVulkan(self: *Self) !void {
        try self.createInstance();
    }

    fn createInstance(self: *Self) !void {
        const vk_proc = @as(vk.PfnGetInstanceProcAddr, @ptrCast(&glfw.getInstanceProcAddress));
        self.vkb = try BaseDispatch.load(vk_proc);

        const glfw_exts = glfw.getRequiredInstanceExtensions() orelse return blk: {
            const err = glfw.mustGetError();
            std.log.err("Failed to get required vulkan instance extensions: error={s}", .{err.description});
            break :blk error.code;
        };

        var instance_extensions = try std.ArrayList([*:0]const u8).initCapacity(std.heap.page_allocator, glfw_exts.len + 1);
        defer instance_extensions.deinit();
        try instance_extensions.appendSlice(glfw_exts);

        const app_info = vk.ApplicationInfo{
            .p_application_name = "Application name",
            .application_version = vk.makeApiVersion(0, 0, 0, 0),
            .p_engine_name = "No Engine",
            .engine_version = vk.makeApiVersion(0, 0, 0, 0),
            .api_version = vk.makeApiVersion(0, 1, 1, 0),
        };

        const create_info = vk.InstanceCreateInfo{
            .flags = .{},
            .p_application_info = &app_info,
            .enabled_layer_count = 0,
            .pp_enabled_layer_names = undefined,
            .enabled_extension_count = @intCast(instance_extensions.items.len),
            .pp_enabled_extension_names = @ptrCast(instance_extensions.items),
        };

        self.instance = try self.vkb.createInstance(&create_info, null);
        self.vki = try InstanceDispatch.load(self.instance, self.vkb.dispatch.vkGetInstanceProcAddr);
    }

    fn mainLoop(self: *Self) !void {
        while (!self.window.shouldClose()) {
            glfw.pollEvents();
        }
    }

    pub fn deinit(self: *Self) void {
        self.vki.destroyInstance(self.instance, null);
        self.window.destroy();
        glfw.terminate();
    }
};

pub fn main() !void {
    var app = Application.init("Vulkan triangle", 800, 600);
    defer app.deinit();
    app.run() catch |err| {
        std.log.err("Application exited with error: {any}", .{err});
        return err;
    };
}
