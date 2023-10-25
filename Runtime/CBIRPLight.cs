
using UdonSharp;
using UnityEngine;
using VRC;
using VRC.SDKBase;
using VRC.Udon;

#if !COMPILER_UDONSHARP && UNITY_EDITOR
using UdonSharpEditor;
using UnityEditor;
using System.Threading.Tasks;
#endif

namespace CBIRP
{
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class CBIRPLight : UdonSharpBehaviour
    {
        public bool destroyComponent = true;
        public int lightType = 0;

        public Color color = Color.white;
        public float intensity = 1f;
        public float range = 5f;

        [Range(0f, 100f)] public float innerAnglePercent = 70f;
        [Range(0f, 179f)] public float outerAngle = 45f;

        public bool shadowMask = false;
        public bool specularOnlyShadowmask = false;

        public MeshRenderer meshRenderer;
        private MaterialPropertyBlock _propertyBlock;
        private Light _unityLight;
        [Tooltip("Automatically copied from the unity light")]
        [SerializeField] private int _shadowMaskID = -1;

        private int _Data0ID;
        private int _Data1ID;
        private int _Data2ID;
        //private int _Data3ID;

        private Vector4 _data0 = new Vector4();
        private Vector4 _data1 = new Vector4();
        private Vector4 _data2 = new Vector4();
        //private Vector4 _data3 = new Vector4();


        private bool _initialized = false;
        private void Initialize()
        {
            _Data0ID = VRCShader.PropertyToID("_Data0");
            _Data1ID = VRCShader.PropertyToID("_Data1");
            _Data2ID = VRCShader.PropertyToID("_Data2");
            //_Data3ID = VRCShader.PropertyToID("_Data3");
            _propertyBlock = new MaterialPropertyBlock();

            _initialized = true;
        }

        void Start()
        {
            Initialize();
            UpdateLight();

            if (destroyComponent)
            {
                Destroy(this);
            }
        }

        public void UpdateLight()
        {
            _propertyBlock = new MaterialPropertyBlock();
            _data0 = color;
            _data0.w = intensity;

            _data1.x = range;
            _data1.y = innerAnglePercent;
            _data1.z = outerAngle;
            _data1.w = lightType;

            _data2.x = shadowMask ? _shadowMaskID : -1;
            _data2.y = specularOnlyShadowmask ? 1f : 0f;

            _propertyBlock.SetVector(_Data0ID, _data0);
            _propertyBlock.SetVector(_Data1ID, _data1);
            _propertyBlock.SetVector(_Data2ID, _data2);
            //_propertyBlock.SetVector(_Data3ID, _data3);
            meshRenderer.SetPropertyBlock(_propertyBlock);
        }

#if UNITY_EDITOR && !COMPILER_UDONSHARP
        // baking output not initliazed right at start 
        async void CopyShadowMaskID()
        {
            await Task.Delay(1000);

            if (Application.isPlaying || !_unityLight)
            {
                return;
            }

            int channel = _unityLight.bakingOutput.occlusionMaskChannel;

            if (_shadowMaskID != channel)
            {
                _shadowMaskID = channel;
                this.MarkDirty();
                UpdateLight();
            }
        }
        void OnValidate()
        {
            if (!_initialized)
            {
                Initialize();
            }

            if (!_unityLight)
            {
                _unityLight = GetComponent<Light>();
            }
            if (_unityLight)
            {
                CopyShadowMaskID();
            }

            UpdateLight();
        }
#endif
    }

    #if !COMPILER_UDONSHARP && UNITY_EDITOR
    [CustomEditor(typeof(CBIRPLight)), CanEditMultipleObjects]
    public class CBIRPLightEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target)) return;

            base.OnInspectorGUI();
            var l = (CBIRPLight)target;
            if (targets.Length > 1)
            {
                return;
            }
    #if BAKERY_INCLUDED

            var bakeryLight = l.gameObject.GetComponent<BakeryPointLight>();
            if (bakeryLight && GUILayout.Button("Match Bakery Light to this Light"))
            {
                bakeryLight.color = l.color;
                bakeryLight.realisticFalloff = true;
                if (l.shadowMask)
                {
                    bakeryLight.shadowmask = l.shadowMask;
                    bakeryLight.bakeToIndirect = l.specularOnlyShadowmask;
                }
                else
                {
                    bakeryLight.shadowmask = false;
                    bakeryLight.bakeToIndirect = false;
                }

                bakeryLight.angle = l.outerAngle;
                bakeryLight.innerAngle = l.innerAnglePercent;
                bakeryLight.intensity = l.intensity;
                bakeryLight.projMode = l.lightType == 1 ?
                    BakeryPointLight.ftLightProjectionMode.Omni :
                    BakeryPointLight.ftLightProjectionMode.Cone;
                bakeryLight.cutoff = l.range;
                bakeryLight.MarkDirty();

            }
    #endif
        }
    }
    #endif
}