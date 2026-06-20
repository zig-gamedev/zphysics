const std = @import("std");
const c = @import("jolt_c");
const zphysics = @import("zphysics");

pub fn main() void {
    const print = std.debug.print;
    const separator = "================================================================================";

    print("\n{s}\n", .{separator});
    print("  C vs Zig Struct Size and Offset Detailed Analysis Report\n", .{});
    print("{s}\n\n", .{separator});

    // ============ 1. CollideShapeResult ============
    print("{s}\n", .{separator});
    print("1. CollideShapeResult Analysis\n", .{});
    print("{s}\n\n", .{separator});

    print("C Struct (JPC_CollideShapeResult):\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(c.JPC_CollideShapeResult)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(c.JPC_CollideShapeResult)});

    print("Zig Struct:\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(zphysics.CollideShapeResult)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(zphysics.CollideShapeResult)});

    print("C Struct Field Offsets:\n", .{});
    print("  shape1_contact_point:    {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape1_contact_point")});
    print("  shape2_contact_point:    {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape2_contact_point")});
    print("  penetration_axis:        {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "penetration_axis")});
    print("  penetration_depth:       {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "penetration_depth")});
    print("  shape1_sub_shape_id:     {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape1_sub_shape_id")});
    print("  shape2_sub_shape_id:     {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape2_sub_shape_id")});
    print("  body2_id:                {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "body2_id")});
    print("  shape1_face:             {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape1_face")});
    print("  shape2_face:             {d}\n", .{@offsetOf(c.JPC_CollideShapeResult, "shape2_face")});

    print("\nZig Struct Field Offsets:\n", .{});
    print("  shape1_contact_point:    {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "shape1_contact_point")});
    print("  shape2_contact_point:    {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "shape2_contact_point")});
    print("  penetration_axis:        {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "penetration_axis")});
    print("  penetration_depth:       {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "penetration_depth")});
    print("  shape1_sub_shape_id:     {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "shape1_sub_shape_id")});
    print("  shape2_sub_shape_id:     {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "shape2_sub_shape_id")});
    print("  body2_id:                {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "body2_id")});
    print("  shape1_face:             {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "shape1_face")});
    print("  shape2_face:             {d}\n", .{@offsetOf(zphysics.CollideShapeResult, "shape2_face")});

    // ============ 2. ContactManifold ============
    print("\n{s}\n", .{separator});
    print("2. ContactManifold Analysis\n", .{});
    print("{s}\n\n", .{separator});

    print("C Struct (JPC_ContactManifold):\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(c.JPC_ContactManifold)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(c.JPC_ContactManifold)});

    print("Zig Struct:\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(zphysics.ContactManifold)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(zphysics.ContactManifold)});

    print("C Struct Field Offsets:\n", .{});
    print("  base_offset:                {d}\n", .{@offsetOf(c.JPC_ContactManifold, "base_offset")});
    print("  normal:                     {d}\n", .{@offsetOf(c.JPC_ContactManifold, "normal")});
    print("  penetration_depth:          {d}\n", .{@offsetOf(c.JPC_ContactManifold, "penetration_depth")});
    print("  shape1_sub_shape_id:        {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape1_sub_shape_id")});
    print("  shape2_sub_shape_id:        {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape2_sub_shape_id")});
    print("  shape1_relative_contact:    {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape1_relative_contact")});
    print("  shape2_relative_contact:    {d}\n", .{@offsetOf(c.JPC_ContactManifold, "shape2_relative_contact")});

    print("\nZig Struct Field Offsets:\n", .{});
    print("  base_offset:                {d}\n", .{@offsetOf(zphysics.ContactManifold, "base_offset")});
    print("  normal:                     {d}\n", .{@offsetOf(zphysics.ContactManifold, "normal")});
    print("  penetration_depth:          {d}\n", .{@offsetOf(zphysics.ContactManifold, "penetration_depth")});
    print("  shape1_sub_shape_id:        {d}\n", .{@offsetOf(zphysics.ContactManifold, "shape1_sub_shape_id")});
    print("  shape2_sub_shape_id:        {d}\n", .{@offsetOf(zphysics.ContactManifold, "shape2_sub_shape_id")});
    print("  shape1_relative_contact:    {d}\n", .{@offsetOf(zphysics.ContactManifold, "shape1_relative_contact")});
    print("  shape2_relative_contact:    {d}\n", .{@offsetOf(zphysics.ContactManifold, "shape2_relative_contact")});

    // ============ 3. BodyCreationSettings ============
    print("\n{s}\n", .{separator});
    print("3. BodyCreationSettings Analysis\n", .{});
    print("{s}\n\n", .{separator});

    print("C Struct (JPC_BodyCreationSettings):\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(c.JPC_BodyCreationSettings)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(c.JPC_BodyCreationSettings)});

    print("Zig Struct:\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(zphysics.BodyCreationSettings)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(zphysics.BodyCreationSettings)});

    print("C Struct Key Field Offsets:\n", .{});
    print("  position:                      {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "position")});
    print("  rotation:                      {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "rotation")});
    print("  user_data:                     {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "user_data")});
    print("  object_layer:                  {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "object_layer")});
    print("  collision_group:               {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "collision_group")});
    print("  motion_type:                   {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "motion_type")});
    print("  allowed_DOFs:                  {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "allowed_DOFs")});
    print("  allow_dynamic_or_kinematic:    {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "allow_dynamic_or_kinematic")});
    print("  is_sensor:                     {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "is_sensor")});
    print("  motion_quality:                {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "motion_quality")});
    print("  shape:                         {d}\n", .{@offsetOf(c.JPC_BodyCreationSettings, "shape")});

    print("\nZig Struct Key Field Offsets:\n", .{});
    print("  position:                      {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "position")});
    print("  rotation:                      {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "rotation")});
    print("  user_data:                     {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "user_data")});
    print("  object_layer:                  {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "object_layer")});
    print("  collision_group:               {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "collision_group")});
    print("  motion_type:                   {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "motion_type")});
    print("  allowed_DOFs:                  {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "allowed_DOFs")});
    print("  allow_dynamic_or_kinematic:    {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "allow_dynamic_or_kinematic")});
    print("  is_sensor:                     {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "is_sensor")});
    print("  motion_quality:                {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "motion_quality")});
    print("  shape:                         {d}\n", .{@offsetOf(zphysics.BodyCreationSettings, "shape")});

    // ============ 4. CharacterVirtualSettings ============
    print("\n{s}\n", .{separator});
    print("4. CharacterVirtualSettings Analysis\n", .{});
    print("{s}\n\n", .{separator});

    print("C Struct (JPC_CharacterVirtualSettings):\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(c.JPC_CharacterVirtualSettings)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(c.JPC_CharacterVirtualSettings)});

    print("Zig Struct:\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(zphysics.CharacterVirtualSettings)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(zphysics.CharacterVirtualSettings)});

    print("C Struct Field Offsets:\n", .{});
    print("  base:                         {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "base")});
    print("  mass:                         {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "mass")});
    print("  max_strength:                 {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "max_strength")});
    print("  shape_offset:                 {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "shape_offset")});
    print("  back_face_mode:               {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "back_face_mode")});
    print("  max_num_hits:                 {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "max_num_hits")});
    print("  inner_body_shape:             {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "inner_body_shape")});
    print("  inner_body_layer:             {d}\n", .{@offsetOf(c.JPC_CharacterVirtualSettings, "inner_body_layer")});

    print("\nZig Struct Field Offsets:\n", .{});
    print("  base:                         {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "base")});
    print("  mass:                         {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "mass")});
    print("  max_strength:                 {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "max_strength")});
    print("  shape_offset:                 {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "shape_offset")});
    print("  back_face_mode:               {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "back_face_mode")});
    print("  max_num_hits:                 {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "max_num_hits")});
    print("  inner_body_shape:             {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "inner_body_shape")});
    print("  inner_body_layer:             {d}\n", .{@offsetOf(zphysics.CharacterVirtualSettings, "inner_body_layer")});

    // ============ 5. CharacterBaseSettings ============
    print("\n{s}\n", .{separator});
    print("5. CharacterBaseSettings Analysis\n", .{});
    print("{s}\n\n", .{separator});

    print("C Struct (JPC_CharacterBaseSettings):\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(c.JPC_CharacterBaseSettings)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(c.JPC_CharacterBaseSettings)});

    print("Zig Struct:\n", .{});
    print("  Size: {d} bytes\n", .{@sizeOf(zphysics.CharacterBaseSettings)});
    print("  Alignment: {d} bytes\n\n", .{@alignOf(zphysics.CharacterBaseSettings)});

    print("C Struct Field Offsets:\n", .{});
    print("  up:                           {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "up")});
    print("  supporting_volume:            {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "supporting_volume")});
    print("  max_slope_angle:              {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "max_slope_angle")});
    print("  enhanced_internal_edge_removal: {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "enhanced_internal_edge_removal")});
    print("  shape:                        {d}\n", .{@offsetOf(c.JPC_CharacterBaseSettings, "shape")});

    print("\nZig Struct Field Offsets:\n", .{});
    print("  up:                           {d}\n", .{@offsetOf(zphysics.CharacterBaseSettings, "up")});
    print("  supporting_volume:            {d}\n", .{@offsetOf(zphysics.CharacterBaseSettings, "supporting_volume")});
    print("  max_slope_angle:              {d}\n", .{@offsetOf(zphysics.CharacterBaseSettings, "max_slope_angle")});
    print("  enhanced_internal_edge_removal: {d}\n", .{@offsetOf(zphysics.CharacterBaseSettings, "enhanced_internal_edge_removal")});
    print("  shape:                        {d}\n", .{@offsetOf(zphysics.CharacterBaseSettings, "shape")});

    // ============ 6. Helper Types ============
    print("\n{s}\n", .{separator});
    print("6. Helper Type Size Analysis\n", .{});
    print("{s}\n\n", .{separator});

    print("SubShapeId:   C={d},  Zig={d}\n", .{@sizeOf(c.JPC_SubShapeID), @sizeOf(zphysics.SubShapeId)});
    print("BodyId:       C={d},  Zig={d}\n", .{@sizeOf(c.JPC_BodyID), @sizeOf(zphysics.BodyId)});
    print("AllowedDOFs:  C={d},  Zig={d}\n", .{@sizeOf(c.JPC_AllowedDOFs), @sizeOf(zphysics.AllowedDOFs)});
    print("MotionType:   C={d},  Zig={d}\n", .{@sizeOf(c.JPC_MotionType), @sizeOf(zphysics.MotionType)});
    print("MotionQuality: C={d}, Zig={d}\n", .{@sizeOf(c.JPC_MotionQuality), @sizeOf(zphysics.MotionQuality)});
    print("ObjectLayer:  C={d},  Zig={d}\n", .{@sizeOf(c.JPC_ObjectLayer), @sizeOf(zphysics.ObjectLayer)});
    print("BackFaceMode: C={d},  Zig={d}\n", .{@sizeOf(c.JPC_BackFaceMode), @sizeOf(zphysics.BackFaceMode)});

    print("\n{s}\n", .{separator});
    print("Analysis Complete\n", .{});
    print("{s}\n", .{separator});
}