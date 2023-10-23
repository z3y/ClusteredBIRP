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

            float _Udon_CBIRP_ConeRadii[128];

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
                positionWS += CBIRP_PLAYER_POS;

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
                for (uint lightIndex = 1; lightIndex < CBIRP_MAX_LIGHTS && packIndex < 4; lightIndex++)
                {
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
                    float3 positionToLight = (lightPositionWS - positionWS);


                    float3 lightPosMin = lightPositionWS - r;
                    float3 lightPosMax = lightPositionWS + r;

                    UNITY_BRANCH
                    if (all(
                            positionMax.xz > lightPosMin.xz && positionMax.xz < lightPosMax.xz ||
                            positionMin.xz > lightPosMin.xz && positionMin.xz < lightPosMax.xz ||
                            positionMin.xz < lightPositionWS.xz && positionMax.xz > lightPositionWS.xz
                            
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
                        if (dot(positionToLight, positionToLight) < r)
                        {
                            // UNITY_BRANCH
                            // TODO: fix spot culling
                            if (isSpot)
                            {
                                // thanks iq https://iquilezles.org/articles/diskbbox/
                                // float rangeSqr = sqrt(light.range);

                                // // precalculated in udon
                                // // float spotAngle = _Udon_CBIRP_SpotAngles[lightIndex];
                                // // float angleA = (spotAngle * (UNITY_PI / 180)) * 0.5f;
                                // // float cosAngleA = cos(angleA);
                                // // float angleB = UNITY_PI * 0.5f - angleA;
                                // // float coneRadius = rangeSqr * cosAngleA * sin(angleA) / sin(angleB);
                                // float coneRadius = _Udon_CBIRP_ConeRadii[lightIndex];
                                // float3 coneEnd = lightPositionWS + light.direction * rangeSqr;
                                // float3 coneStart = lightPositionWS;

                                // float3 pa = coneStart;
                                // float3 pb = coneEnd;
                                // float ra = 0;
                                // float rb = coneRadius;
                                // float3 a = pb - pa;
                                // float3 e = sqrt( 1.0 - a*a/dot(a,a) );
                                // float3 coneMin =  min( pa - e*ra, pb - e*rb );
                                // float3 coneMax = max( pa + e*ra, pb + e*rb );
                                // coneMin -= offset;
                                // coneMax += offset;

                                // if (!all(
                                //     positionMax.xz > coneMin.xz && positionMax.xz < coneMax.xz ||
                                //     positionMin.xz > coneMin.xz && positionMin.xz < coneMax.xz                                 
                                // )) continue;
                            }
                            if (packShift >= 32)
                            {
                                packShift = 0;
                                packIndex++;
                                if (packIndex >= 5) break;
                            }
                            lightIndices[packIndex] |= (lightIndex) << packShift; // compiler doesnt like it as uint4
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
                for (uint lightIndex = 1; lightIndex < CBIRP_MAX_PROBES && packIndex < 4; lightIndex++)
                {

                    CBIRP::ReflectionProbe probe = CBIRP::ReflectionProbe::DecodeReflectionProbe(lightIndex);

                    if (probe.intensity == 0)
                    {
                        break;
                    }

                    // UnpackFloat(data1, boxMin, boxMax);
                    float3 probePosition = probe.positionWS;
                    float3 boxMin = probe.boxMin;
                    float3 boxMax = probe.boxMax;

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
                            positionMax.xz >= boxMin.xz && positionMax.xz <= boxMax.xz ||
                            positionMin.xz >= boxMin.xz && positionMin.xz <= boxMax.xz ||
                            positionMin.xz < probePosition.xz && positionMax.xz > probePosition.xz
                            
                        ) && insideY)
                    {
                        if (packShift >= 32)
                        {
                            packShift = 0;
                            packIndex++;
                            if (packIndex >= 5) break;
                        }
                        lightIndices[packIndex] |= (lightIndex) << packShift; // compiler doesnt like it as uint4
                        packShift += CBIRP_CULLING_INDEX_BITS;
                    }
                }


                return uint4(lightIndices[0], lightIndices[1], lightIndices[2], lightIndices[3]);
            }
            ENDCG
        }
    }
}
