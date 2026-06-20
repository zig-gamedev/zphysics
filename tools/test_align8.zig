const std = @import("std");
const c = @import("jolt_c");

// Try using align(8) to match C's alignment
const TestMassProperties = extern struct {
    mass: f32, // 0-3
    _pad: [4]u8, // 4-7 - 4 bytes padding for 8-byte alignment (not 16!)
    inertia: [64]u8, // 8-71
};

const TestBodyCreationSettings = extern struct {
    position: [4]f32 align(8), // 0-15 (changed from align(16) to align(8))
    rotation: [4]f32 align(8), // 16-31
    linear_velocity: [4]f32 align(8), // 32-47
    angular_velocity: [4]f32 align(8), // 48-63
    user_data: u64, // 64-71
    object_layer: u16, // 72-73
    _pad0: [6]u8, // 74-79
    collision_group: extern struct {
        filter: ?*const anyopaque, // 80-87
        group_id: u32, // 88-91
        sub_group_id: u32, // 92-95
    }, // 80-95
    motion_type: u8, // 96
    allowed_DOFs: u8, // 97
    allow_dynamic_or_kinematic: bool, // 98
    is_sensor: bool, // 99
    collide_kinematic_vs_non_dynamic: bool, // 100
    use_manifold_reduction: bool, // 101
    apply_gyroscopic_force: bool, // 102
    motion_quality: u8, // 103
    enhanced_internal_edge_removal: bool, // 104
    allow_sleeping: bool, // 105
    _pad1: [2]u8, // 106-107
    friction: f32, // 108-111
    restitution: f32, // 112-115
    linear_damping: f32, // 116-119
    angular_damping: f32, // 120-123
    max_linear_velocity: f32, // 124-127
    max_angular_velocity: f32, // 128-131
    gravity_factor: f32, // 132-135
    num_velocity_steps_override: u32, // 136-139
    num_position_steps_override: u32, // 140-143
    override_mass_properties: u32, // 144-147
    inertia_multiplier: f32, // 148-151
    mass_properties_override: TestMassProperties, // 152-223 (72 bytes)
    reserved: ?*const anyopaque, // 224-231
    shape: ?*const anyopaque, // 232-239
};

pub fn main() void {
    std.debug.print("TestBodyCreationSettings (with align(8) on fields):\n", .{});
    std.debug.print("  Size: {d} (C expects 240)\n", .{@sizeOf(TestBodyCreationSettings)});
    std.debug.print("  Align: {d} (C expects 8)\n", .{@alignOf(TestBodyCreationSettings)});
    std.debug.print("  shape offset: {d} (C expects 232)\n", .{@offsetOf(TestBodyCreationSettings, "shape")});
    std.debug.print("  reserved offset: {d} (C expects 224)\n", .{@offsetOf(TestBodyCreationSettings, "reserved")});

    // Test instantiation
    const settings = TestBodyCreationSettings{
        .position = .{ 0.0, -1.0, 0.0, 1.0 },
        .rotation = .{ 0.0, 0.0, 0.0, 1.0 },
        .linear_velocity = .{ 0.0, 0.0, 0.0, 0.0 },
        .angular_velocity = .{ 0.0, 0.0, 0.0, 0.0 },
        .user_data = 0,
        .object_layer = 1,
        ._pad0 = [_]u8{ 0, 0, 0, 0, 0, 0 },
        .collision_group = .{
            .filter = null,
            .group_id = 0,
            .sub_group_id = 0,
        },
        .motion_type = 0,
        .allowed_DOFs = 0,
        .allow_dynamic_or_kinematic = false,
        .is_sensor = false,
        .collide_kinematic_vs_non_dynamic = false,
        .use_manifold_reduction = true,
        .apply_gyroscopic_force = false,
        .motion_quality = 0,
        .enhanced_internal_edge_removal = false,
        .allow_sleeping = true,
        ._pad1 = [_]u8{ 0, 0 },
        .friction = 0.2,
        .restitution = 0.0,
        .linear_damping = 0.05,
        .angular_damping = 0.05,
        .max_linear_velocity = 500.0,
        .max_angular_velocity = 0.25 * 3.14159 * 60.0,
        .gravity_factor = 1.0,
        .num_velocity_steps_override = 0,
        .num_position_steps_override = 0,
        .override_mass_properties = 0,
        .inertia_multiplier = 1.0,
        .mass_properties_override = .{
            .mass = 0.0,
            ._pad = [_]u8{ 0, 0, 0, 0 },
            .inertia = @as([64]u8, @splat(0)),
        },
        .reserved = null,
        .shape = null,
    };

    const bytes = std.mem.asBytes(&settings);
    std.debug.print("\nBytes at 224-239 (reserved + shape):\n", .{});
    var i: usize = 224;
    while (i < 240) : (i += 1) {
        std.debug.print("  [{d}] {x:0>2}\n", .{ i, bytes[i] });
    }
}