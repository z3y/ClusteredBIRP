using UdonSharp;
using UnityEngine;
using VRC.SDKBase;

#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEditor;
#endif

namespace CBIRP
{
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class CBIRPManager : UdonSharpBehaviour
    {
        public float cullFar = 100f;
        public CustomRenderTexture clustering;
        public RenderTexture uniforms;
        public Texture2D shadowmask;
        public CubemapArray reflectionProbeArray;
        //public Cubemap skyProbe;

        private void Start()
        {
            SetGlobalUniforms();
            Destroy(this);
        }

        public void SetGlobalUniforms()
        {
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_Uniforms"), uniforms);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_Culling"), clustering);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ShadowMask"), shadowmask);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ReflectionProbes"), reflectionProbeArray);
            //VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_SkyProbe"), skyProbe);
        }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
        public void OnValidate()
        {
            SetGlobalUniforms();
        }
#endif
    }


#if UNITY_EDITOR && !COMPILER_UDONSHARP
    [CustomEditor(typeof(CBIRPManager))]
    class CBIRPManagerInspector : Editor
    {
        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            if (GUILayout.Button("Pack Probes"))
            {
                CBIRPManagerEditor.PackProbes((CBIRPManager)target);
            }
        }
    }

#endif
}