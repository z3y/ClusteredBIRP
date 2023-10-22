#ifndef CBIRP_INCLUDED
#define CBIRP_INCLUDED

#include "Constants.hlsl"
#include "Filament.hlsl"

Texture2D<float4> _Udon_CBIRP_Uniforms;
Texture2D<uint4> _Udon_CBIRP_Culling;
TextureCubeArray _Udon_CBIRP_ReflectionProbes;
TextureCube _Udon_CBIRP_SkyProbe;
SamplerState sampler_Udon_CBIRP_ReflectionProbes;
Texture2D _Udon_CBIRP_ShadowMask;

    // uint4 indices = _Udon_CBIRP_Culling[clusterIndex]; \/ this was slower
#define CBIRP_CLUSTER_START(clusterIndex) \
    uint indices[4] = {_Udon_CBIRP_Culling[clusterIndex].x, _Udon_CBIRP_Culling[clusterIndex].y, _Udon_CBIRP_Culling[clusterIndex].z, _Udon_CBIRP_Culling[clusterIndex].w}; \
    uint index = indices[0] & 0x000000ff; \
    uint offset = 0; \
    [loop] while (true) { \
        UNITY_BRANCH if (index == 0) { break; } \

#define CBIRP_CLUSTER_END \
        offset += 8; \
        uint mask = (0x000000ff << offset); \
        uint componentIndex = offset / 32; \
        index = (indices[componentIndex] & mask) >> offset; \
        index = offset < 128 ? index : 0; \
    } \

uniform float _Udon_CBIRP_CullFar;
uniform float4 _Udon_CBIRP_PlayerCamera;
uniform float4 _Udon_CBIRP_ProbeDecodeInstructions;

// #ifdef CBIRP_GLOBAL_UNIFORMS
// cbuffer CBIRP_Uniforms
// {
//     uniform float4 _Udon_CBIRP_Light0[CBIRP_MAX_LIGHTS];
//     uniform float4 _Udon_CBIRP_Light1[CBIRP_MAX_LIGHTS];
//     uniform float4 _Udon_CBIRP_Light2[CBIRP_MAX_LIGHTS];
//     uniform float4 _Udon_CBIRP_Light3[CBIRP_MAX_LIGHTS];

//     uniform float4 _Udon_CBIRP_Probe0[CBIRP_MAX_PROBES];
//     uniform float4 _Udon_CBIRP_Probe1[CBIRP_MAX_PROBES];
//     uniform float4 _Udon_CBIRP_Probe2[CBIRP_MAX_PROBES];
// };
// #endif

namespace CBIRP
{
    // from filament
    float GetSquareFalloffAttenuation(float distanceSquare, float lightInvRadius2)
    {
        float factor = distanceSquare * lightInvRadius2;
        float smoothFactor = saturate(1.0 - factor * factor);
        return (smoothFactor * smoothFactor) / max(distanceSquare, 1e-4);
    }
    
    // modified attenuation up close, inv square falloff is too bright
    float GetSquareFalloffAttenuationCustom(float distanceSquare, float lightInvRadius2)
    {
        float factor = distanceSquare * lightInvRadius2;
        float smoothFactor = saturate(1.0 - factor * factor);
        return (smoothFactor * smoothFactor) / (distanceSquare + 1.0);
    }

    float GetSpotAngleAttenuation(float3 spotForward, float3 l, float spotScale, float spotOffset)
    {
        float cd = dot(-spotForward, l);
        float attenuation = saturate(cd * spotScale + spotOffset);
        return attenuation * attenuation;
    }

    float3 Heatmap(float v)
    {
        float3 r = v * 2.1 - float3(1.8, 1.14, 0.3);
        return 1.0 - r * r;
    }

    struct Light
    {
        float3 positionWS;
        float range;
        bool spot;
        bool enabled;
        float3 color;
        bool shadowmask;
        uint shadowmaskID;
        float3 direction;
        half spotOffset;
        half spotScale;
        bool specularOnly;

        static Light DecodeLight(uint index)
        {
            Light l = (Light)0;
            float4 data0 = _Udon_CBIRP_Uniforms[uint2(index, 0)];
            data0.y += _Udon_CBIRP_Uniforms[uint2(index, 1)] * 0.01;
            // data0.y += _Udon_CBIRP_Uniforms[uint2(index, 2)] * 0.01;
            // data0.y += _Udon_CBIRP_Uniforms[uint2(index, 3)] * 0.01;
            // data0.y += _Udon_CBIRP_Uniforms[uint2(index, 4)] * 0.01;
            // data0.y += _Udon_CBIRP_Uniforms[uint2(index, 5)] * 0.01;
            // data0.y += _Udon_CBIRP_Uniforms[uint2(index, 6)] * 0.01;
            // float4 data0 = _Udon_CBIRP_Light0[index];
            // float4 data1 = _Udon_CBIRP_Light1[index];
            // float4 data2 = _Udon_CBIRP_Light2[index];
            // float4 data3 = _Udon_CBIRP_Light3[index];
            // l.enabled = data0.w != 0;
            // l.positionWS = data0.xyz;
            // l.range = data0.w;
            // l.spot = data2.w == 1;
            // l.direction = data2.xyz;
            // l.color = data1.xyz;
            // l.shadowmaskID = data1.w;
            // l.shadowmask = data1.w >= 0;
            // l.spotScale = data3.x;
            // l.spotOffset = data3.y;
            // l.specularOnly = data3.z;


            l.enabled = data0.w != 0;
            l.positionWS = data0.xyz;
            l.range = 25;
            l.spot = false;
            l.direction = 0;
            l.color = float3(533,4,2);
            l.shadowmaskID = -1;
            l.shadowmask = false;
            l.spotScale = 0;
            l.spotOffset = 0;
            l.specularOnly = false;

            return l;
        }
    };

    struct ReflectionProbe
    {
        // data0
        float3 positionWS;
        half intensity;
        bool boxProjection;

        // data 1
        float3 boxMin;
        float arrayIndex;
        
        //data 2
        float3 boxMax;
        half blendDistance;

        static ReflectionProbe DecodeReflectionProbe(uint index)
        {
            ReflectionProbe p = (ReflectionProbe)0;
            // float4 data0 = _Udon_CBIRP_Probe0[index];
            // float4 data1 = _Udon_CBIRP_Probe1[index];
            // float4 data2 = _Udon_CBIRP_Probe2[index];
            // p.positionWS = data0.xyz;
            // p.intensity = abs(data0.w);
            // p.boxProjection = data0.w > 0.0;
            // p.arrayIndex = data1.w;
            // p.boxMin = data1.xyz;
            // p.boxMax = data2.xyz;
            // p.blendDistance = data2.w;

            return p;
        }
    };

    // Normalize that account for vectors with zero length
    float3 SafeNormalize(float3 inVec)
    {
        const float flt_min = 1.175494351e-38;
        float dp3 = max(flt_min, dot(inVec, inVec));
        return inVec * rsqrt(dp3);
    }

    uint2 CullIndex(float3 positionWS)
    {
        uint3 grid = uint3(((positionWS - CBIRP_PLAYER_POS) + CBIRP_CULL_FAR) / float(CBIRP_VOXELS_SIZE));
        #ifdef CBIRP_ASSUME_NO_Y
            uint2 index_2d = uint2(grid.x, grid.z);
        #else
            uint2 index_2d = uint2(grid.x + grid.z * CBIRP_VOXELS_COUNT, grid.y);
        #endif

        return index_2d;
    }

    void ComputeLights(uint2 clusterIndex, float3 positionWS, float3 normalWS, float3 viewDirectionWS, half3 f0, half NoV, half roughness, half4 shadowmask, inout half3 diffuse, inout half3 specular)
    {
        half clampedRoughness = max(roughness * roughness, 0.002);
        half debug = 0;

        CBIRP_CLUSTER_START(clusterIndex)

debug+=1;
            Light light = Light::DecodeLight(index);

            float3 positionToLight = light.positionWS - positionWS;
            float distanceSquare = dot(positionToLight, positionToLight);

            UNITY_BRANCH
            if (distanceSquare < light.range)
            {
                light.range = 1.0 / light.range;
                float3 L = normalize(positionToLight);
                half NoL = saturate(dot(normalWS, L));
                // float attenuation = GetSquareFalloffAttenuation(distanceSquare, light.range);
                float attenuation = GetSquareFalloffAttenuationCustom(distanceSquare, light.range);

                if (light.spot)
                {
                    attenuation *= GetSpotAngleAttenuation(light.direction, L, light.spotScale, light.spotOffset);
                }


                #ifdef LIGHTMAP_ON
                if (light.shadowmask)
                {
                    attenuation *= shadowmask[light.shadowmaskID];
                }
                #endif

                debug += attenuation > 0;

                UNITY_BRANCH
                if (attenuation > 0 && NoL > 0)
                {
                    half3 currentDiffuse = attenuation * light.color * NoL;

                    float3 halfVector = CBIRP::SafeNormalize(L + viewDirectionWS);
                    half LoH = saturate(dot(L, halfVector));

                    #if !defined(CBIRP_LOW) && !defined(LIGHTMAP_ON)
                        half burley = CBIRPFilament::Fd_Burley(roughness, NoV, NoL, LoH);
                        currentDiffuse *= burley;
                    #endif

                    diffuse += currentDiffuse * !light.specularOnly;

                    #ifndef _SPECULARHIGHLIGHTS_OFF
                        half vNoH = saturate(dot(normalWS, halfVector));
                        half vLoH = saturate(dot(L, halfVector));
                        half3 Fv = CBIRPFilament::F_Schlick(vLoH, f0);
                        half Dv = CBIRPFilament::D_GGX(vNoH, clampedRoughness);
                        half Vv = CBIRPFilament::V_SmithGGXCorrelatedFast(NoV, NoL, clampedRoughness);
                        half3 currentSpecular = max(0.0, (Dv * Vv) * Fv) * currentDiffuse;
                        specular += currentSpecular;
                    #endif
                }

            }
        CBIRP_CLUSTER_END

        #ifdef _CBIRP_DEBUG
            // diffuse = Heatmap((debug) / 16.);
            diffuse = debug / 32.;
        #endif

        specular *= UNITY_PI;
    }

    half3 BoxProjectedCubemapDirection(half3 reflectionWS, float3 positionWS, float3 cubemapPositionWS, float3 boxMin, float3 boxMax, bool boxProjection)
    {
        UNITY_FLATTEN // most likely box always
        if (boxProjection)
        {
            float3 boxMinMax = (reflectionWS > 0.0f) ? boxMax.xyz : boxMin.xyz;
            half3 rbMinMax = half3(boxMinMax - positionWS) / reflectionWS;

            half fa = half(min(min(rbMinMax.x, rbMinMax.y), rbMinMax.z));

            half3 worldPos = half3(positionWS - cubemapPositionWS.xyz);

            half3 result = worldPos + reflectionWS * fa;
            return result;
        }
        else
        {
            return reflectionWS;
        }
    }

    half PerceptualRoughnessToMipmapLevel(half perceptualRoughness, uint maxMipLevel)
    {
        perceptualRoughness = perceptualRoughness * (1.7 - 0.7 * perceptualRoughness);

        return perceptualRoughness * maxMipLevel;
    }

    half PerceptualRoughnessToMipmapLevel(half perceptualRoughness)
    {
        return PerceptualRoughnessToMipmapLevel(perceptualRoughness, UNITY_SPECCUBE_LOD_STEPS);
    }

    float CalculateProbeWeight(float3 positionWS, float3 probeBoxMin, float3 probeBoxMax, float blendDistance)
    {
        float3 weightDir = min(positionWS - probeBoxMin.xyz, probeBoxMax.xyz - positionWS) / blendDistance;
        return saturate(min(weightDir.x, min(weightDir.y, weightDir.z)));
    }

    // half CalculateProbeVolumeSqrMagnitude(float4 probeBoxMin, float4 probeBoxMax)
    // {
    //     half3 maxToMin = half3(probeBoxMax.xyz - probeBoxMin.xyz);
    //     return dot(maxToMin, maxToMin);
    // }

    #define FLT_EPSILON     1.192092896e-07 // Smallest positive number, such that 1.0 + FLT_EPSILON != 1.0

    float PositivePow(float base, float power)
    {
        return pow(max(abs(base), float(FLT_EPSILON)), power);
    }
 
    half3 DecodeHDREnvironment(half4 encodedIrradiance, half4 decodeInstructions)
    {
        // Take into account texture alpha if decodeInstructions.w is true(the alpha value affects the RGB channels)
        half alpha = max(decodeInstructions.w * (encodedIrradiance.a - 1.0) + 1.0, 0.0);

        // If Linear mode is not supported we can skip exponent part
        return (decodeInstructions.x * PositivePow(alpha, decodeInstructions.y)) * encodedIrradiance.rgb;
    }


    void ProbesClusterOffset(inout uint2 clusterIndex)
    {
        clusterIndex.y += CBIRP_CULLING_SIZE.y / 2;
    }

    half3 SampleProbes(uint2 clusterIndex, half3 reflectVector, float3 positionWS, half perceptualRoughness)
    {
        return 0;
        // half mip = PerceptualRoughnessToMipmapLevel(perceptualRoughness);
        // float debug = 0;
        // half3 irradiance = 0;
        // float totalWeight = 0;

        // half4 decodeInstructions = _Udon_CBIRP_ProbeDecodeInstructions;

        // ProbesClusterOffset(clusterIndex);

        // CBIRP_CLUSTER_START(clusterIndex)
        //     ReflectionProbe probe = ReflectionProbe::DecodeReflectionProbe(index);
        //     debug += 1;

        //     float weight = CalculateProbeWeight(positionWS, probe.boxMin, probe.boxMax, probe.blendDistance);

        //     UNITY_BRANCH
        //     if (weight > 0.0)
        //     {
        //         weight = min(weight, 1.0 - totalWeight);
        //         totalWeight += weight;

        //         half3 reflectVectorBox = BoxProjectedCubemapDirection(reflectVector, positionWS, probe.positionWS, probe.boxMin, probe.boxMax, probe.boxProjection);
        //         half4 encodedIrradiance = half4(_Udon_CBIRP_ReflectionProbes.SampleLevel(sampler_Udon_CBIRP_ReflectionProbes, half4(reflectVectorBox, probe.arrayIndex), mip));
        //         irradiance += weight * DecodeHDREnvironment(encodedIrradiance, half4(probe.intensity, decodeInstructions.yzw));
        //     }

        // CBIRP_CLUSTER_END

        // #ifdef CBIRP_SKYPROBE
        // UNITY_BRANCH
        // if (totalWeight < 0.99f)
        // {
        //     half4 encodedIrradiance = half4(_Udon_CBIRP_SkyProbe.SampleLevel(sampler_Udon_CBIRP_ReflectionProbes, half3(reflectVector), mip));
        //     irradiance += (1.0f - totalWeight) * encodedIrradiance;
        // }
        // #endif

        // #ifdef _CBIRP_DEBUG
        // return debug / 16.;
        // #endif
        // return irradiance;
    }
}

#endif