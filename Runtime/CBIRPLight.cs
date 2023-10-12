#if !COMPILER_UDONSHARP && UNITY_EDITOR
using UnityEditor;
using UnityEngine;
using VRC;

namespace z3y
{
    [ExecuteAlways]
    public class CBIRPLight : MonoBehaviour
    {
        public bool dynamicTransform = false;
        public LightType type = LightType.Point;
        public Color color = Color.white;
        public float intensity = 1f;
        public float range = 3f;

        [Range(0f, 100f)] public float innerAnglePercent = 70f;
        [Range(0f, 180f)] public float outerAngle = 45f;

        // private MaterialPropertyBlock _propertyBlock;
        //private MeshRenderer _meshRenderer;

        public bool shadowMask = false;
        public bool specularOnlyShadowmask = false;
        internal int _shadowMaskID = -1;

        //public bool flickering = false;
        //[Range(0f, 1f)] public float flickerIntenisty = 0.1f;
        //[Range(0f, 1f)] public float flickerSpeed = 0.2f;
        private Light _light;

        public enum LightType
        {
            Point,
            Spot
        }


        void Start()
        {
            CBIRPManagerEditor.instance.AddLight(this);
            if (Application.isPlaying)
            {
                //_meshRenderer.SetPropertyBlock(null);
                //Destroy(this);
                return;
            }
            //OnValidate();
        }

        private void OnValidate()
        {
            InitializeLight();
        }
        public void InitializeLight()
        {
            _light = GetComponent<Light>();
        }

        public void CopyShadowmaskID()
        {
            if (!_light)
            {
                return;
            }

            _shadowMaskID = shadowMask ? _light.bakingOutput.occlusionMaskChannel : -1;
        }



        private void OnDestroy()
        {
            CBIRPManagerEditor.instance.AddLight(this);
        }
        /*
                public Vector4 GetData0() => new Vector4(color.r, color.g, color.b, intensity);
                public Vector4 GetData1() => new Vector4(range, (outerAngle / 100f) * innerAnglePercent, outerAngle, type == LightType.Spot ? 1 : 0);
                public Vector4 GetData2() => new Vector4(shadowMask ? _shadowMaskID : -1f, flickerSpeed, flickering ? flickerIntenisty : 0, 0);


                private void OnValidate()
                {
                    var unityLight = GetComponent<Light>();
                    if (unityLight)
                    {
                        _shadowMaskID = unityLight.bakingOutput.occlusionMaskChannel;
                        //Debug.Log(_shadowMaskID);
                    }

                    if (_propertyBlock == null)
                    {
                        _meshRenderer = GetComponent<MeshRenderer>();
                        _propertyBlock = new MaterialPropertyBlock();

                        if (_meshRenderer.HasPropertyBlock())
                        {
                            _meshRenderer.GetPropertyBlock(_propertyBlock);
                        }
                    }

                    var prop0 = GetData0();
                    var prop1 = GetData1();
                    var prop2 = GetData2();


                    _propertyBlock.SetVector("_Property0", prop0);
                    _propertyBlock.SetVector("_Property1", prop1);
                    _propertyBlock.SetVector("_Property2", prop2);

                    _meshRenderer.SetPropertyBlock(_propertyBlock);

                }*/
    }
    [CustomEditor(typeof(CBIRPLight))]
    public class CBIRPLightEditor : Editor
    {
        public override void OnInspectorGUI()
        {
            base.OnInspectorGUI();
            var l = (CBIRPLight)target;
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
                bakeryLight.projMode = l.type == CBIRPLight.LightType.Point ? 
                    BakeryPointLight.ftLightProjectionMode.Omni :
                    BakeryPointLight.ftLightProjectionMode.Cone;
                bakeryLight.MarkDirty();

            }
#endif
        }
    }
}
#endif