using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using UnityEngine.SceneManagement;
using System.IO;

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
        [Tooltip("Sample the lowest mip from a global texture and use as light color, for example from a video player screen")]
        public Texture colorTexture;
        //public Texture2D generatedIesLut;
        public CubemapArray reflectionProbeArray;
        //public Cubemap skyProbe;
        [SerializeField] private Camera _trackingCamera;
        [Tooltip("Enable updates to any of the light or probe variables at runtime (Position, Rotation, Color, Range etc). Disable to skip the additional camera used to track them")]
        [SerializeField] private bool _dynamicUpdates = true;
        [Range(0, 5)] public int probeBounces = 1;
        public int probeResolution = 128;
        //public int probeMultiSampling = 1;

        private int _cbirpPlayerPositionID;
        private VRCPlayerApi _localPlayer;
        private void Start()
        {
            SetGlobalUniforms();
            SetDynamicUpdatesState(_dynamicUpdates);
            _localPlayer = Networking.LocalPlayer;
            _cbirpPlayerPositionID = VRCShader.PropertyToID("_Udon_CBIRP_PlayerPosition");
        }
        
        private void Update()
        {
            // an update loop had to be added just in case it breaks in the future as its broken in editor in 2022
            // getting the main camera position is not very accurate in custom render textures
            // also saves 1 extra texture sample previously used
            Vector4 pos = _localPlayer.GetPosition();
            pos.w = cullFar;
            VRCShader.SetGlobalVector(_cbirpPlayerPositionID, pos);
        }

        public void SetGlobalUniforms()
        {
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_Uniforms"), uniforms);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_Clusters"), clustering);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ShadowMask"), shadowmask);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ReflectionProbes"), reflectionProbeArray);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ColorTexture"), colorTexture);

            //VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_IES"), generatedIesLut);

            //VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_SkyProbe"), skyProbe);
        }

        public void SetDynamicUpdatesState(bool isEnabled)
        {
            SendCustomEventDelayedFrames(
                isEnabled ? nameof(EnableDynamicUpdates) : nameof(DisableDynamicUpdates),
                2, VRC.Udon.Common.Enums.EventTiming.Update);
        }
        public void DisableDynamicUpdates() => _trackingCamera.gameObject.SetActive(false);
        public void EnableDynamicUpdates() => _trackingCamera.gameObject.SetActive(true);

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
            if (GUILayout.Button("Bake And Pack Reflection Probes"))
            {
                var m = (CBIRPManager)target;
                CBIRPManagerEditor.ClearProbes(m);
                CBIRPManagerEditor.BakeAndPackProbes(m, m.probeBounces, m.probeResolution);
            }
        }
    }

#endif
}