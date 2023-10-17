
using System.IO;
using UdonSharp;
using UnityEditor;
using UnityEngine;
using VRC;
using VRC.SDK3.Data;
using VRC.SDKBase;

#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEngine.SceneManagement;
using System.Linq;
#endif

namespace z3y
{
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class CBIRPManager : UdonSharpBehaviour
    {
        public float cullFar = 100f;
        public CustomRenderTexture lightCull;
        public Texture2D shadowmask;
        public CubemapArray reflectionProbeArray;
        public Cubemap skyProbe;

        // probes, assumed all static at runtime and always active
        const int _probesSize = 64;
        [SerializeField] internal Vector4[] _probe0 = new Vector4[_probesSize];
        [SerializeField] internal Vector4[] _probe1 = new Vector4[_probesSize];
        [SerializeField] internal Vector4[] _probe2 = new Vector4[_probesSize];
        [SerializeField] internal Vector4[] _probe3 = new Vector4[_probesSize];
        [SerializeField] internal Vector4 _probeDecodeInstructions = new Vector4();

        // lights
        const int _lightSize = 256;
        [SerializeField] internal Transform[] _lightTransforms;
        [SerializeField] internal bool[] _lightDynamicAll;
        [SerializeField] internal float[] _lightsRange;
        [SerializeField] internal Color[] _lightsColor;
        [SerializeField] internal float[] _lightsIntensity;
        [SerializeField] internal int[] _lightsShadowmask;
        [SerializeField] internal byte[] _lightsType;
        [SerializeField] internal float[] _lightsOuterAngle;
        [SerializeField] internal float[] _lightsInnerAnglePercent;
        [SerializeField] internal bool[] _specualOnly;
        private Vector4[] _light0all = new Vector4[_lightSize];
        private Vector4[] _light1all = new Vector4[_lightSize];
        private Vector4[] _light2all = new Vector4[_lightSize];
        private Vector4[] _light3all = new Vector4[_lightSize];
        private int[] _uniformIndexPtr = new int[_lightSize]; // index of all lights mapped to uniform

        // enabled lights only
        private DataList _lightDynamic = new DataList(); // update only enabled non static light positions, rotations and enabled state
        private int[] _lightIndexPtr = new int[_lightSize]; // index of the enabled light mapped to all lights
        // light uniforms
        private Vector4[] _light0 = new Vector4[_lightSize];
        private Vector4[] _light1 = new Vector4[_lightSize];
        private Vector4[] _light2 = new Vector4[_lightSize];
        private Vector4[] _light3 = new Vector4[_lightSize];
        // for culling only
        private float[] _lightConeRadii = new float[_lightSize];


        private int _Udon_CBIRP_Light0;
        private int _Udon_CBIRP_Light1;
        private int _Udon_CBIRP_Light2;
        private int _Udon_CBIRP_Light3;

        private int _Udon_CBIRP_PlayerCamera;
        private int _Udon_CBIRP_CullFar;
        private int _Udon_CBIRP_ConeRadii;

        VRCPlayerApi _localPlayer;

        void Start()
        {
            _localPlayer = Networking.LocalPlayer;
            InitializePropertyIDs();
            SetGlobalUniforms();
            UpdateProbeGlobals();


            for (int i = 0; i < _lightTransforms.Length; i++)
            {
                ComputeLightUniforms(i);
            }
            CopyActiveLights();
            UpdateLightGlobals();
            UpdateCullFar(cullFar);
        }

        private void Update()
        {

            VRCShader.SetGlobalVector(_Udon_CBIRP_PlayerCamera, _localPlayer.GetPosition());

            var dynLights = _lightDynamic.Count;
            if (dynLights == 0)
            {
                return;
            }

            bool updateActiveLights = false;
            for (int i = 0; i < dynLights; i++)
            {
                var lptr = (int)_lightDynamic[i];
                var t = _lightTransforms[lptr];
                var uptr = _uniformIndexPtr[lptr];

                if (uptr <= 0) // light disabled
                {
                    if (t.gameObject.activeInHierarchy)
                    {
                        updateActiveLights = t.gameObject.activeInHierarchy;
                    }
                    continue;
                }

                if (!t.gameObject.activeInHierarchy)
                {
                    updateActiveLights = true;
                }


                // update position
                var w = _light0[uptr].w;
                _light0[uptr] = t.position;
                _light0[uptr].w = w;

                // update angle for spot lights
                var w2 = _light2[uptr].w;
                _light2[uptr] = t.forward;
                _light2[uptr].w = w2;
            }

            // for position and rotation only
            if (updateActiveLights)
            {
                CopyActiveLights(); // rebuild active lights
                VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light1, _light1);
                VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light3, _light3);
            }

            VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light0, _light0);
            VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light2, _light2);
        }


        public void InitializePropertyIDs()
        {
            _Udon_CBIRP_Light0 = VRCShader.PropertyToID("_Udon_CBIRP_Light0");
            _Udon_CBIRP_Light1 = VRCShader.PropertyToID("_Udon_CBIRP_Light1");
            _Udon_CBIRP_Light2 = VRCShader.PropertyToID("_Udon_CBIRP_Light2");
            _Udon_CBIRP_Light3 = VRCShader.PropertyToID("_Udon_CBIRP_Light3");
            _Udon_CBIRP_PlayerCamera = VRCShader.PropertyToID("_Udon_CBIRP_PlayerCamera");
            _Udon_CBIRP_CullFar = VRCShader.PropertyToID("_Udon_CBIRP_CullFar");
            _Udon_CBIRP_ConeRadii = VRCShader.PropertyToID("_Udon_CBIRP_ConeRadii");
        }

        public void UpdateCullFar(float far)
        {
            VRCShader.SetGlobalFloat(_Udon_CBIRP_CullFar, far);
        }

        public void UpdateLightGlobals()
        {

            VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light0, _light0);
            VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light1, _light1);
            VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light2, _light2);
            VRCShader.SetGlobalVectorArray(_Udon_CBIRP_Light3, _light3);
        }

        public void UpdateProbeGlobals()
        {
            VRCShader.SetGlobalVectorArray(VRCShader.PropertyToID("_Udon_CBIRP_Probe0"), _probe0);
            VRCShader.SetGlobalVectorArray(VRCShader.PropertyToID("_Udon_CBIRP_Probe1"), _probe1);
            VRCShader.SetGlobalVectorArray(VRCShader.PropertyToID("_Udon_CBIRP_Probe2"), _probe2);
            VRCShader.SetGlobalVectorArray(VRCShader.PropertyToID("_Udon_CBIRP_Probe3"), _probe3);
            VRCShader.SetGlobalVector(VRCShader.PropertyToID("_Udon_CBIRP_ProbeDecodeInstructions"), _probeDecodeInstructions);

            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_SkyProbe"), skyProbe);
        }

    /*    public void SetCrtUniforms()
        {
            _lightConeRadii = new float[_lightSize];
            int j = 0;
            for (int i = 0; i < _lightTransforms.Length; i++)
            {
                var t = _lightTransforms[i];
                if (!t.gameObject.activeInHierarchy)
                {
                    continue;
                }
                j++;

                if (_lightsType[i] != 1)
                {
                    continue;
                }
                float rangeSqr = _lightsRange[i];
                float spotAngle = _lightsOuterAngle[i];
                float angleA = spotAngle * (Mathf.PI / 180) * 0.5f;
                float cosAngleA = Mathf.Cos(angleA);
                float angleB = Mathf.PI * 0.5f - angleA;
                float coneRadius = rangeSqr * cosAngleA * Mathf.Sin(angleA) / Mathf.Sin(angleB);

                _lightConeRadii[j-1] = coneRadius;

            }

            lightCull.material.SetFloatArray(_Udon_CBIRP_ConeRadii, _lightConeRadii);
        }*/

        public Vector4 GetLightData0(int index)
        {
            Vector4 result = _lightTransforms[index].position;
            //float rangeInv = 1.0f / _lightsRange[index];
            float range = _lightsRange[index];
            result.w = range * range;
            return result;
        }
        public Vector4 GetLightData1(int index)
        {
            Vector4 result = _lightsColor[index] * _lightsIntensity[index];
            result.w = _lightsShadowmask[index];
            return result;
        }
        public Vector4 GetLightData2(int index) // type0 = point, type1 = spot, type2 directional
        {
            Vector4 result = _lightTransforms[index].forward;
            result.w = _lightsType[index];
            return result;
        }
        public Vector4 GetLightData3(int index)
        {
            float outerAngle = _lightsOuterAngle[index];
            float innerAngle = (outerAngle / 100f) * _lightsInnerAnglePercent[index];
            innerAngle = innerAngle / 360 * Mathf.PI;
            outerAngle = outerAngle / 360 * Mathf.PI;
            float cosOuter = Mathf.Cos(outerAngle);
            float spotScale = 1.0f / Mathf.Max(Mathf.Cos(innerAngle) - cosOuter, 1e-4f);
            float spotOffset = -cosOuter * spotScale;

            Vector4 result = new Vector4(spotScale, spotOffset, _specualOnly[index] ? 1 : 0, 0);
            return result;
        }

        public void InitializeLightsCount(int count)
        {
            _lightTransforms = new Transform[count];
            _lightDynamicAll = new bool[count];
            _lightsRange = new float[count];
            _lightsColor = new Color[count];
            _lightsIntensity = new float[count];
            _lightsShadowmask = new int[count];
            _lightsType = new byte[count];
            _lightsOuterAngle = new float[count];
            _lightsInnerAnglePercent = new float[count];
            _specualOnly = new bool[count];
        }

        public void ComputeLightUniforms(int index)
        {
            _light0all[index] = GetLightData0(index);
            _light1all[index] = GetLightData1(index);
            _light2all[index] = GetLightData2(index);
            _light3all[index] = GetLightData3(index);
        }
        private void ClearLightUniforms()
        {
            _light0 = new Vector4[_lightSize];
            _light1 = new Vector4[_lightSize];
            _light2 = new Vector4[_lightSize];
            _light3 = new Vector4[_lightSize];
            _lightIndexPtr = new int[_lightSize];
            _lightDynamic.Clear();
        }

        public void CopyActiveLights()
        {
            ClearLightUniforms();
            int activeLights = 0;
            for (int i = 0; i < _lightTransforms.Length; i++)
            {
                var t = _lightTransforms[i];

                if (_lightDynamicAll[i])
                {
                    _lightDynamic.Add(i);
                }

                if (!t.gameObject.activeInHierarchy)
                {
                    _uniformIndexPtr[i] = -1;
                    continue;
                }

                _light0[activeLights] = _light0all[i];
                _light1[activeLights] = _light1all[i];
                _light2[activeLights] = _light2all[i];
                _light3[activeLights] = _light3all[i];

                _lightIndexPtr[activeLights] = i;
                _uniformIndexPtr[i] = activeLights;
                activeLights++;
            }
            //SetCrtUniforms();
        }




        public void SetGlobalUniforms()
        {
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_Culling"), lightCull);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ShadowMask"), shadowmask);
            VRCShader.SetGlobalTexture(VRCShader.PropertyToID("_Udon_CBIRP_ReflectionProbes"), reflectionProbeArray);
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
                PackProbes((CBIRPManager)target);
            }
        }

        public static void PackProbes(CBIRPManager target)
        {
            // thx error mdl
            // https://github.com/Error-mdl/UnityReflectionProbeArrays/blob/master/ReflectionProbeArray/editor/ReflectionProbeArrayCreator.cs

            var fbreflectionProbes = FindObjectsOfType<CBIRPReflectionProbe>();

            if (fbreflectionProbes.Length == 0)
            {
                return;
            }

            var reflectionProbes = fbreflectionProbes.Select(x => x.GetComponent<ReflectionProbe>()).ToArray();

            var referenceProbe = reflectionProbes[0].texture as Cubemap;
            var array = new CubemapArray(referenceProbe.width, reflectionProbes.Length, referenceProbe.format, true);

            for (int i = 0; i < reflectionProbes.Length; i++)
            {
                Texture probe = reflectionProbes[i].texture;

                for (int mip = 0; mip < referenceProbe.mipmapCount; mip++)
                {
                    for (int side = 0; side < 6; side++)
                    {
                        Graphics.CopyTexture(probe, side, mip, array, (i * 6) + side, mip);
                    }
                }

                var cbirpProbe = reflectionProbes[i].transform.GetComponent<CBIRPReflectionProbe>();
                if (cbirpProbe)
                {
                    cbirpProbe.cubeArrayIndex = i;
                    cbirpProbe.MarkDirty();
                }
            }

            var scenePath = SceneManager.GetActiveScene().path;
            var sceneName = Path.GetFileNameWithoutExtension(scenePath);
            var sceneDirectory = Path.GetDirectoryName(scenePath);
            var path = Path.Combine(sceneDirectory, "CBIRP_Probes_" + sceneName + ".asset");
            AssetDatabase.CreateAsset(array, path);
            AssetDatabase.ImportAsset(path);
            var probes = AssetDatabase.LoadAssetAtPath<CubemapArray>(path);
            var instance = target;
            instance.reflectionProbeArray = probes;
            instance.MarkDirty();
            instance.OnValidate();

        }
    }

#endif
}