// #define DEBUG_LIGHT_BRANCH
// #define DEBUG_PROBE_BRANCH


#ifdef UNITY_PBS_USE_BRDF2
    #define CBIRP_LOW
#endif

// #define CBIRP_CULL_FAR _Udon_CBIRP_CullFar
// #define CBIRP_CULL_FAR _ProjectionParams.z
// #define CBIRP_CULL_FAR 100
// #define CBIRP_PLAYER_POS _WorldSpaceCameraPos.xyz
// #define CBIRP_PLAYER_POS _Udon_CBIRP_PlayerCamera.xyz

#define CBIRP_PLAYER_POS _Udon_CBIRP_PlayerPosition.xyz
#define CBIRP_CULL_FAR _Udon_CBIRP_PlayerPosition.w


#include "ConstantsGenerated.hlsl"

#define CBIRP_CULLING_SIZE uint(1024)
#define CBIRP_VOXELS_COUNT CBIRP_CULLING_SIZE
#define CBIRP_VOXELS_SIZE CBIRP_CULL_FAR / float(CBIRP_CULLING_SIZE / 2.0)

#define CBIRP_UNIFORMS_SIZE uint2(128, 4)
#define CBIRP_UNIFORMS_PROBE_START 4

