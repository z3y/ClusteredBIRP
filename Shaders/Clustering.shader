Shader "CBIRP/Internal/Clustering"
{
    Properties
    {
        [HideInInspector] _MainTex ("Texture", 2D) = "white" {}
        [NoScaleOffset] _Udon_CBIRP_Uniforms ("Uniforms", 2D) = "black" {}

    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Cull Off
        Lighting Off
        ZWrite Off
        ZTest Always

        Pass
        {
            Name "Lights"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 4.5

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "CBIRP.hlsl"
            #include "UnityCustomRenderTexture.cginc"

            uint4 frag (v2f_customrendertexture i) : SV_Target
            {
                float voxel_size = CBIRP_VOXELS_SIZE;
                uint2 uv_scaled = uint2(i.localTexcoord.xy * CBIRP_CULLING_SIZE);
                uint dimension = uint(i.localTexcoord.x * 3);
                float position = uv_scaled.y;

                position *= CBIRP_VOXELS_SIZE;
                position -= CBIRP_CULL_FAR - CBIRP_VOXELS_SIZE;
                position += CBIRP_PLAYER_POS[dimension];

                float positionMin = position - CBIRP_VOXELS_SIZE;
                float positionMax = position;

                uint flags[4] = { 0, 0, 0, 0 };

                [loop]
                for (uint index = 1; index < CBIRP_MAX_LIGHTS; index++)
                {
                    CBIRP::Light light =  CBIRP::Light::DecodeLight(index);

                    if (!light.enabled)
                    {
                        break;
                    }

                    float r = sqrt(light.range);
                    r = max(r, CBIRP_VOXELS_SIZE);
                    bool isSpot = light.spot;
                    float lightPosition = light.positionWS[dimension];

                    float positionToLight = (lightPosition - position);
                    float lightPosMin = lightPosition - r;
                    float lightPosMax = lightPosition + r;

                    if (positionMax > lightPosMin && positionMax < lightPosMax ||
                        positionMin > lightPosMin && positionMin < lightPosMax)
                    {
                        uint component = index / 32;
                        flags[component] |= 0x1 << (index - (component * 32));
                    }
                }

                return uint4(flags[0], flags[1], flags[2], flags[3]);
            }
            ENDCG
        }
        Pass
        {
            Name "Probes"
            CGPROGRAM
            #pragma vertex CustomRenderTextureVertexShader
            #pragma fragment frag
            #pragma target 4.5

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            #include "CBIRP.hlsl"
            #include "UnityCustomRenderTexture.cginc"

            uint4 frag (v2f_customrendertexture i) : SV_Target
            {
                float voxel_size = CBIRP_VOXELS_SIZE;
                uint2 uv_scaled = uint2(i.localTexcoord.xy * CBIRP_CULLING_SIZE);
                //uint dimension = uint(i.localTexcoord.x * 4);
                float3 position = uv_scaled.y;

                position *= CBIRP_VOXELS_SIZE;
                position -= CBIRP_CULL_FAR - CBIRP_VOXELS_SIZE;
                position += CBIRP_PLAYER_POS;

                float3 positionMin = position - CBIRP_VOXELS_SIZE;
                float3 positionMax = position;

                uint4 flags = 0;

                [loop]
                for (uint index = 1; index < CBIRP_MAX_PROBES; index++)
                {
                    CBIRP::ReflectionProbe probe = CBIRP::ReflectionProbe::DecodeReflectionProbe(index);

                    if (probe.intensity == 0)
                    {
                        break;
                    }

                    float3 probePosition = probe.positionWS;
                    float3 boxMin = probe.boxMin;
                    float3 boxMax = probe.boxMax;

                    if (positionMax.x > boxMin.x && positionMax.x < boxMax.x ||
                        positionMin.x > boxMin.x && positionMin.x < boxMax.x)
                    {
                        flags.x |= 0x1 << (index);
                    }
                    if (positionMax.y > boxMin.y && positionMax.y < boxMax.y ||
                        positionMin.y > boxMin.y && positionMin.y < boxMax.y)
                    {
                        flags.y |= 0x1 << (index);
                    }
                    if (positionMax.z > boxMin.z && positionMax.z < boxMax.z ||
                        positionMin.z > boxMin.z && positionMin.z < boxMax.z)
                    {
                        flags.z |= 0x1 << (index);
                    }
                }
                

                return flags;
            }
            ENDCG
        }
    }
}
