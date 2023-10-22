
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

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
        private int _shadowMaskID = -1;

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

            _data2.x = _shadowMaskID;
            _data2.y = specularOnlyShadowmask ? 1f : 0f;

            _propertyBlock.SetVector(_Data0ID, _data0);
            _propertyBlock.SetVector(_Data1ID, _data1);
            _propertyBlock.SetVector(_Data2ID, _data2);
            //_propertyBlock.SetVector(_Data3ID, _data3);
            meshRenderer.SetPropertyBlock(_propertyBlock);
        }

#if UNITY_EDITOR
        private void OnValidate()
        {
            if (!_initialized)
            {
                Initialize();
            }

            UpdateLight();
        }
#endif
    }
}