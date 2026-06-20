const std = @import("std");
const assert = std.debug.assert;
const c = @cImport({
    @cDefine("JPC_ENABLE_ASSERTS", "1");
    @cInclude("JoltPhysicsC.h");
});

const Real = f32;
const rvec_align = 16;

pub fn main() void {
    std.debug.print("\n========== C Struct Sizes (from JoltPhysicsC.h) ==========\n", .{});
    std.debug.print("JPC_CollideShapeResult: {d} bytes\n", .{@sizeOf(c.JPC_CollideShapeResult)});
    std.debug.print("JPC_ContactManifold: {d} bytes\n", .{@sizeOf(c.JPC_ContactManifold)});
    std.debug.print("JPC_BodyCreationSettings: {d} bytes\n", .{@sizeOf(c.JPC_BodyCreationSettings)});
    std.debug.print("JPC_CharacterVirtualSettings: {d} bytes\n", .{@sizeOf(c.JPC_CharacterVirtualSettings)});
    std.debug.print("JPC_CharacterBaseSettings: {d} bytes\n", .{@sizeOf(c.JPC_CharacterBaseSettings)});
    std.debug.print("JPC_MassProperties: {d} bytes\n", .{@sizeOf(c.JPC_MassProperties)});
    std.debug.print("JPC_CollisionGroup: {d} bytes\n", .{@sizeOf(c.JPC_CollisionGroup)});
    std.debug.print("JPC_AllowedDOFs (u8): {d} bytes\n", .{@sizeOf(c.JPC_AllowedDOFs)});

    std.debug.print("\n========== C Struct Offsets ==========\n", .{});
    
    // CollideShapeResult offsets
    std.debug.print("\nJPC_CollideShapeResult offsets:\n", .{});
    std.debug.print("  shape1_contact_point: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape1_contact_point")});
    std.debug.print("  shape2_contact_point: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape2_contact_point")});
    std.debug.print("  penetration_axis: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "penetration_axis")});
    std.debug.print("  penetration_depth: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "penetration_depth")});
    std.debug.print("  shape1_sub_shape_id: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape1_sub_shape_id")});
    std.debug.print("  shape2_sub_shape_id: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape2_sub_shape_id")});
    std.debug.print("  body2_id: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "body2_id")});
    std.debug.print("  shape1_face: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape1_face")});
    std.debug.print("  shape2_face: {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape2_face")});
    
    // ContactManifold offsets
    std.debug.print("\nJPC_ContactManifold offsets:\n", .{});
    std.debug.print("  base_offset: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "base_offset")});
    std.debug.print("  normal: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "normal")});
    std.debug.print("  penetration_depth: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "penetration_depth")});
    std.debug.print("  shape1_sub_shape_id: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape1_sub_shape_id")});
    std.debug.print("  shape2_sub_shape_id: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape2_sub_shape_id")});
    std.debug.print("  shape1_relative_contact: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape1_relative_contact")});
    std.debug.print("  shape2_relative_contact: {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape2_relative_contact")});
    
    // BodyCreationSettings offsets
    std.debug.print("\nJPC_BodyCreationSettings offsets:\n", .{});
    std.debug.print("  position: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "position")});
    std.debug.print("  rotation: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "rotation")});
    std.debug.print("  linear_velocity: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "linear_velocity")});
    std.debug.print("  angular_velocity: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "angular_velocity")});
    std.debug.print("  user_data: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "user_data")});
    std.debug.print("  object_layer: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "object_layer")});
    std.debug.print("  collision_group: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "collision_group")});
    std.debug.print("  motion_type: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "motion_type")});
    std.debug.print("  allowed_DOFs: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "allowed_DOFs")});
    std.debug.print("  allow_dynamic_or_kinematic: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "allow_dynamic_or_kinematic")});
    std.debug.print("  is_sensor: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "is_sensor")});
    std.debug.print("  collide_kinematic_vs_non_dynamic: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "collide_kinematic_vs_non_dynamic")});
    std.debug.print("  use_manifold_reduction: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "use_manifold_reduction")});
    std.debug.print("  apply_gyroscopic_force: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "apply_gyroscopic_force")});
    std.debug.print("  motion_quality: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "motion_quality")});
    std.debug.print("  enhanced_internal_edge_removal: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "enhanced_internal_edge_removal")});
    std.debug.print("  allow_sleeping: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "allow_sleeping")});
    std.debug.print("  friction: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "friction")});
    std.debug.print("  restitution: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "restitution")});
    std.debug.print("  linear_damping: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "linear_damping")});
    std.debug.print("  angular_damping: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "angular_damping")});
    std.debug.print("  max_linear_velocity: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "max_linear_velocity")});
    std.debug.print("  max_angular_velocity: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "max_angular_velocity")});
    std.debug.print("  gravity_factor: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "gravity_factor")});
    std.debug.print("  num_velocity_steps_override: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "num_velocity_steps_override")});
    std.debug.print("  num_position_steps_override: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "num_position_steps_override")});
    std.debug.print("  override_mass_properties: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "override_mass_properties")});
    std.debug.print("  inertia_multiplier: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "inertia_multiplier")});
    std.debug.print("  mass_properties_override: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "mass_properties_override")});
    std.debug.print("  reserved: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "reserved")});
    std.debug.print("  shape: {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "shape")});
    
    // CharacterVirtualSettings offsets
    std.debug.print("\nJPC_CharacterVirtualSettings offsets:\n", .{});
    std.debug.print("  base: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "base")});
    std.debug.print("  mass: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "mass")});
    std.debug.print("  max_strength: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "max_strength")});
    std.debug.print("  shape_offset: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "shape_offset")});
    std.debug.print("  back_face_mode: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "back_face_mode")});
    std.debug.print("  predictive_contact_distance: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "predictive_contact_distance")});
    std.debug.print("  max_collision_iterations: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "max_collision_iterations")});
    std.debug.print("  max_constraint_iterations: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "max_constraint_iterations")});
    std.debug.print("  min_time_remaining: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "min_time_remaining")});
    std.debug.print("  collision_tolerance: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "collision_tolerance")});
    std.debug.print("  character_padding: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "character_padding")});
    std.debug.print("  max_num_hits: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "max_num_hits")});
    std.debug.print("  hit_reduction_cos_max_angle: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "hit_reduction_cos_max_angle")});
    std.debug.print("  penetration_recovery_speed: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "penetration_recovery_speed")});
    std.debug.print("  inner_body_shape: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "inner_body_shape")});
    std.debug.print("  inner_body_layer: {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "inner_body_layer")});
    
    // CharacterBaseSettings offsets
    std.debug.print("\nJPC_CharacterBaseSettings offsets:\n", .{});
    std.debug.print("  up: {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "up")});
    std.debug.print("  supporting_volume: {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "supporting_volume")});
    std.debug.print("  max_slope_angle: {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "max_slope_angle")});
    std.debug.print("  enhanced_internal_edge_removal: {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "enhanced_internal_edge_removal")});
    std.debug.print("  shape: {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "shape")});
}