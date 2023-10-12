Shader "CBIRP/Internal/Culling"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
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

            Texture2D<float4> _MainTex;

            uint4 frag (v2f_customrendertexture i) : SV_Target
            {
                float voxel_size = CBIRP_VOXELS_SIZE;


                uint2 uv_scaled = uint2(i.localTexcoord.xy * CBIRP_CULLING_SIZE * float2(1, 0.5));


                #ifdef CBIRP_ASSUME_NO_Y
                float3 positionWS = float3(
                    uv_scaled.x,
                    0,
                    uv_scaled.y
                    );
                #else
                float3 positionWS = float3(
                    uv_scaled.x % CBIRP_VOXELS_COUNT,
                    uv_scaled.y,
                    (uv_scaled.x / CBIRP_VOXELS_COUNT) % CBIRP_VOXELS_COUNT 
                    );
                #endif




                positionWS *= voxel_size;
                positionWS -= CBIRP_CULL_FAR - voxel_size;
                positionWS += CBIRP_PLAYER_POS; // replace with something more reliable, like global position from udon

                float3 positionMin = positionWS - voxel_size;
                float3 positionMax = positionWS;

                float c = voxel_size / 2.0;
                positionWS -= float3(c, c, c); // voxel center

                #ifdef CBIRP_ASSUME_NO_Y
                    positionMax.y = 0;
                    positionMin.y = 0;
                    positionWS.y = 0;
                #endif


                float result = 0;

                uint lightIndices[4] = { 0, 0, 0, 0 };
                uint2 packOffset = 0;
                uint packIndex = 0;
                uint packShift = 0;

                [loop]
                for (uint lightIndex = 0; lightIndex < 256 && packIndex < 4; lightIndex++)
                {
                    float4 lightData0 = _MainTex[uint2(lightIndex, 0)];

                    CBIRP::Light light =  CBIRP::Light::DecodeLight(lightIndex);

                    if (!light.enabled)
                    {
                        break;
                    }
                    
                    // if (distance(light.positionWS, CBIRP_PLAYER_POS) > 15.0)
                    // {
                    //     continue;
                    // }

                    float r = sqrt(light.range);
                    bool isSpot = light.spot;
                    float3 lightPositionWS = light.positionWS;

                    bool insideY = (CBIRP_PLAYER_POS.y + lightPositionWS.y - r) < CBIRP_CULL_FAR &&
                                   (CBIRP_PLAYER_POS.y - lightPositionWS.y + r) > -CBIRP_CULL_FAR ;

                                //    insideY = (CBIRP_PLAYER_POS.y + lightPositionWS.y - r) < CBIRP_CULL_FAR; // above
                                //    insideY = (CBIRP_PLAYER_POS.y - lightPositionWS.y + r) > -CBIRP_CULL_FAR; // above

                    #ifdef CBIRP_ASSUME_NO_Y
                        lightPositionWS.y = 0;
                    #endif
                    float3 lightDirection = (lightPositionWS - positionWS);


                    float3 lightPosMin = lightPositionWS - r;
                    float3 lightPosMax = lightPositionWS + r;

                    UNITY_BRANCH
                    if (all(
                            positionMax > lightPosMin && positionMax < lightPosMax ||
                            positionMin > lightPosMin && positionMin < lightPosMax ||
                            positionMin < lightPositionWS && positionMax > lightPositionWS
                            
                        ) && insideY)
                    {
                        #ifdef CBIRP_ASSUME_NO_Y
                            float offset = (sqrt(2.0) * voxel_size) / 2.0; // 2d diagonal
                        #else
                            float offset = (sqrt(3.0) * voxel_size) / 2.0; // 3d diagonal
                        #endif
                        r += offset;
                        r *= r;

                        //UNITY_BRANCH
                        if (dot(lightDirection, lightDirection) < r)
                        {
                            UNITY_BRANCH
                            if (isSpot)
                            {
                                float atten = CBIRP::GetSpotAngleAttenuation(lightDirection, light.direction, 1, offset);
                                if (atten <= 0) continue;
                            }
                            if (packShift >= 32)
                            {
                                packShift = 0;
                                packIndex++;
                                if (packIndex >= 5) break;
                            }
                            lightIndices[packIndex] |= (lightIndex + 1) << packShift; // compiler doesnt like it as uint4
                            packShift += CBIRP_CULLING_INDEX_BITS;
                        }
                    }
                }

                return uint4(lightIndices[0], lightIndices[1], lightIndices[2], lightIndices[3]);
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

            Texture2D<float4> _MainTex;

            uint4 frag (v2f_customrendertexture i) : SV_Target
            {
                float voxel_size = CBIRP_CULL_FAR / float(CBIRP_VOXELS_COUNT / 2.0);

                uint2 uv_scaled = uint2(i.localTexcoord.xy * CBIRP_CULLING_SIZE * float2(1, 0.5));

                #ifdef CBIRP_ASSUME_NO_Y
                float3 positionWS = float3(
                    uv_scaled.x,
                    0,
                    uv_scaled.y
                    );
                #else
                float3 positionWS = float3(
                    uv_scaled.x % CBIRP_VOXELS_COUNT,
                    uv_scaled.y,
                    (uv_scaled.x / CBIRP_VOXELS_COUNT) % CBIRP_VOXELS_COUNT 
                    );
                #endif

                positionWS *= voxel_size;
                positionWS -= CBIRP_CULL_FAR - voxel_size;
                positionWS += CBIRP_PLAYER_POS; // replace with something more reliable, like global position from udon

                
                float c = voxel_size / 2.0;
                // positionWS -= float3(c, c, c); // voxel center
                float3 positionMin = positionWS - voxel_size;
                float3 positionMax = positionWS;

                float result = 0;

                uint lightIndices[4] = { 0, 0, 0, 0 };
                uint2 packOffset = 0;
                uint packIndex = 0;
                uint packShift = 0;

                [loop]
                for (uint lightIndex = 0; lightIndex < 32 && packIndex < 4; lightIndex++)
                {
                    float4 data0 = _MainTex[uint2(lightIndex, 0 + CBIRP_UNIFORMS_PROBE_START)];
                    float4 data1 = _MainTex[uint2(lightIndex, 1 + CBIRP_UNIFORMS_PROBE_START)];
                    float4 data2 = _MainTex[uint2(lightIndex, 2 + CBIRP_UNIFORMS_PROBE_START)];
                    float4 data3 = _MainTex[uint2(lightIndex, 3 + CBIRP_UNIFORMS_PROBE_START)];
#ifdef CBIRP_GLOBAL_UNIFORMS
data0 = _Udon_CBIRP_Probe0[lightIndex];
data1 = _Udon_CBIRP_Probe1[lightIndex];
data2 = _Udon_CBIRP_Probe2[lightIndex];
data3 = _Udon_CBIRP_Probe3[lightIndex];
#endif

                    if (data0.x == 0)
                    {
                        break;
                    }

                    // UnpackFloat(data1, boxMin, boxMax);
                    float4 probePosition = data0;
                    float3 boxMin = data1.xyz;
                    float3 boxMax = data2.xyz;

                    bool insideY = (CBIRP_PLAYER_POS.y + probePosition.y - boxMax.y) < CBIRP_CULL_FAR &&
                                   (CBIRP_PLAYER_POS.y - probePosition.y + boxMin.y) > -CBIRP_CULL_FAR ;

                    #ifdef CBIRP_ASSUME_NO_Y
                        positionMax.y = 0;
                        positionMin.y = 0;
                        boxMin.y = 0;
                        boxMax.y = 0;
                    #endif

                    UNITY_BRANCH
                    if (all(
                            positionMax >= boxMin && positionMax <= boxMax ||
                            positionMin >= boxMin && positionMin <= boxMax ||
                            positionMin < probePosition && positionMax > probePosition
                            
                        ) && insideY)
                    {
                        if (packShift >= 32)
                        {
                            packShift = 0;
                            packIndex++;
                            if (packIndex >= 5) break;
                        }
                        lightIndices[packIndex] |= (lightIndex + 1) << packShift; // compiler doesnt like it as uint4
                        packShift += CBIRP_CULLING_INDEX_BITS;
                    }
                }


                return uint4(lightIndices[0], lightIndices[1], lightIndices[2], lightIndices[3]);
            }
            ENDCG
        }
    }
}
