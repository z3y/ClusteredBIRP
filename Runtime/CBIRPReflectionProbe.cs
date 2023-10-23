
using UdonSharp;
using UnityEngine;
using VRC.SDKBase;
using VRC.Udon;

namespace CBIRP
{
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class CBIRPReflectionProbe : UdonSharpBehaviour
    {
        public bool destroyComponent = true;
        public float blendDistance = 0.1f;
        public int cubeArrayIndex = 0;

        private MaterialPropertyBlock _propertyBlock;
        public MeshRenderer meshRenderer;
        public ReflectionProbe probe;

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
            UpdateProbe();

            if (destroyComponent)
            {
                Destroy(probe);
                Destroy(this);
            }
        }

        public void UpdateProbe()
        {
            meshRenderer.sortingOrder = 128 - probe.importance;

            _propertyBlock = new MaterialPropertyBlock();

            //float intensity = probe.textureHDRDecodeValues.x;
            _data0.x = probe.intensity;
            _data0.y = probe.boxProjection ? 1f : 0f;
            _data0.z = cubeArrayIndex;
            _data0.w = blendDistance;

            _data1 = probe.center;
            _data2 = probe.size;

            _propertyBlock.SetVector(_Data0ID, _data0);
            _propertyBlock.SetVector(_Data1ID, _data1);
            _propertyBlock.SetVector(_Data2ID, _data2);
            //_propertyBlock.SetVector(_Data3ID, _data3);
            meshRenderer.SetPropertyBlock(_propertyBlock);
        }

#if UNITY_EDITOR
        public void OnValidate()
        {
            if (!_initialized)
            {
                Initialize();
            }

            blendDistance = Mathf.Clamp(blendDistance, 0, float.MaxValue);

            UpdateProbe();
        }
#endif
    }
}