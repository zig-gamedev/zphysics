#include <stdio.h>
#include <stddef.h>
#include "JoltPhysicsC.h"

int main() {
    printf("JPC_MassProperties detailed layout:\n");
    printf("  Size: %zu, Align: %zu\n", sizeof(JPC_MassProperties), _Alignof(JPC_MassProperties));
    printf("  mass offset: %zu, size: %zu\n", offsetof(JPC_MassProperties, mass), sizeof(((JPC_MassProperties*)0)->mass));
    printf("  inertia offset: %zu, size: %zu\n", offsetof(JPC_MassProperties, inertia), sizeof(((JPC_MassProperties*)0)->inertia));
    
    // Calculate byte layout
    printf("\nByte layout:\n");
    printf("  mass:       0-3 (4 bytes)\n");
    printf("  (padding):  4-15 (12 bytes due to alignas(16))\n");
    printf("  inertia:    16-79 (64 bytes)\n");
    printf("  Total: 80 bytes\n");
    
    return 0;
}