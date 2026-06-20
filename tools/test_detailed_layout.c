#include <stdio.h>
#include <stddef.h>
#include "JoltPhysicsC.h"

int main() {
    printf("Detailed JPC_BodyCreationSettings layout:\n");
    printf("  Size: %zu, Align: %zu\n\n", sizeof(JPC_BodyCreationSettings), _Alignof(JPC_BodyCreationSettings));
    
    printf("  position:                %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, position), sizeof(((JPC_BodyCreationSettings*)0)->position));
    printf("  rotation:                %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, rotation), sizeof(((JPC_BodyCreationSettings*)0)->rotation));
    printf("  linear_velocity:         %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, linear_velocity), sizeof(((JPC_BodyCreationSettings*)0)->linear_velocity));
    printf("  angular_velocity:        %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, angular_velocity), sizeof(((JPC_BodyCreationSettings*)0)->angular_velocity));
    printf("  user_data:               %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, user_data), sizeof(((JPC_BodyCreationSettings*)0)->user_data));
    printf("  object_layer:            %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, object_layer), sizeof(((JPC_BodyCreationSettings*)0)->object_layer));
    printf("  collision_group:         %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, collision_group), sizeof(((JPC_BodyCreationSettings*)0)->collision_group));
    printf("  motion_type:             %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, motion_type), sizeof(((JPC_BodyCreationSettings*)0)->motion_type));
    printf("  allowed_DOFs:            %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, allowed_DOFs), sizeof(((JPC_BodyCreationSettings*)0)->allowed_DOFs));
    printf("  allow_dynamic_or_kinematic: %zu\n", offsetof(JPC_BodyCreationSettings, allow_dynamic_or_kinematic));
    printf("  is_sensor:               %zu\n", offsetof(JPC_BodyCreationSettings, is_sensor));
    printf("  collide_kinematic_vs_non_dynamic: %zu\n", offsetof(JPC_BodyCreationSettings, collide_kinematic_vs_non_dynamic));
    printf("  use_manifold_reduction:  %zu\n", offsetof(JPC_BodyCreationSettings, use_manifold_reduction));
    printf("  apply_gyroscopic_force:  %zu\n", offsetof(JPC_BodyCreationSettings, apply_gyroscopic_force));
    printf("  motion_quality:          %zu\n", offsetof(JPC_BodyCreationSettings, motion_quality));
    printf("  enhanced_internal_edge_removal: %zu\n", offsetof(JPC_BodyCreationSettings, enhanced_internal_edge_removal));
    printf("  allow_sleeping:          %zu\n", offsetof(JPC_BodyCreationSettings, allow_sleeping));
    printf("  friction:                %zu\n", offsetof(JPC_BodyCreationSettings, friction));
    printf("  restitution:             %zu\n", offsetof(JPC_BodyCreationSettings, restitution));
    printf("  linear_damping:          %zu\n", offsetof(JPC_BodyCreationSettings, linear_damping));
    printf("  angular_damping:         %zu\n", offsetof(JPC_BodyCreationSettings, angular_damping));
    printf("  max_linear_velocity:     %zu\n", offsetof(JPC_BodyCreationSettings, max_linear_velocity));
    printf("  max_angular_velocity:    %zu\n", offsetof(JPC_BodyCreationSettings, max_angular_velocity));
    printf("  gravity_factor:          %zu\n", offsetof(JPC_BodyCreationSettings, gravity_factor));
    printf("  num_velocity_steps_override: %zu\n", offsetof(JPC_BodyCreationSettings, num_velocity_steps_override));
    printf("  num_position_steps_override: %zu\n", offsetof(JPC_BodyCreationSettings, num_position_steps_override));
    printf("  override_mass_properties: %zu\n", offsetof(JPC_BodyCreationSettings, override_mass_properties));
    printf("  inertia_multiplier:      %zu\n", offsetof(JPC_BodyCreationSettings, inertia_multiplier));
    printf("  mass_properties_override: %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, mass_properties_override), sizeof(((JPC_BodyCreationSettings*)0)->mass_properties_override));
    printf("  reserved:                %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, reserved), sizeof(((JPC_BodyCreationSettings*)0)->reserved));
    printf("  shape:                   %zu (size %zu)\n", offsetof(JPC_BodyCreationSettings, shape), sizeof(((JPC_BodyCreationSettings*)0)->shape));
    
    return 0;
}