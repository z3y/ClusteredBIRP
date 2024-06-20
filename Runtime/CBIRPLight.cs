
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
    public enum LightType : int
    {
        Point,
        Spot
    }
    [UdonBehaviourSyncMode(BehaviourSyncMode.None)]
    public class CBIRPLight : UdonSharpBehaviour
    {
        [Tooltip("Destroy Udon component on start to reduce overhead. Lights transform will still be updated, but properties cant be modified.")]public bool destroyComponent = true;
        public LightType lightType = LightType.Point;

        public Color color = Color.white;
        public float intensity = 1f;
        public float range = 5f;

        [Range(0f, 100f)] public float innerAnglePercent = 70f;
        [Range(0f, 179f)] public float outerAngle = 45f;

        public bool shadowMask = false;
        public bool specularOnlyShadowmask = false;
        //public bool ies = false;
        //public AnimationCurve iesCurve = AnimationCurve.Linear(0, 1, 1, 1);
        //[Tooltip("Automatically set by the ies generator")]
        //[SerializeField] private int _iesID = -1;

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
            if (meshRenderer == null)
            {
                meshRenderer = GetComponent<MeshRenderer>();
            }
            _propertyBlock = new MaterialPropertyBlock();
            _data0 = color;
            _data0.w = intensity;

            _data1.x = range;
            _data1.y = innerAnglePercent;
            _data1.z = outerAngle;
            _data1.w = lightType == LightType.Point ? 0 : 1;

            _data2.x = shadowMask ? _shadowMaskID : -1;
            _data2.y = specularOnlyShadowmask ? 1f : 0f;

            _propertyBlock.SetVector(_Data0ID, _data0);
            _propertyBlock.SetVector(_Data1ID, _data1);
            _propertyBlock.SetVector(_Data2ID, _data2);
            //_propertyBlock.SetVector(_Data3ID, _data3);
            meshRenderer.SetPropertyBlock(_propertyBlock);
        }

#if UNITY_EDITOR
        void OnDrawGizmosSelected()
        {
            Gizmos.color = new Color(0.5f, 0.5f, 0.5f, 0.5f);
            if (lightType == LightType.Point)
            {
                Gizmos.DrawWireSphere(transform.position, range);
            }
            else
            {
                Gizmos.DrawLine(transform.position, transform.position + (transform.rotation * (Vector3.forward * 0.5f)));
            }
        }
#endif

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

            /*if (ies)
            {
                CBIRPManagerEditor.GenerateIESLut();
            }*/

            UpdateLight();
        }
#endif
    }

    #if !COMPILER_UDONSHARP && UNITY_EDITOR
    [CustomEditor(typeof(CBIRPLight)), CanEditMultipleObjects]
    public class CBIRPLightEditor : Editor
    {

        SerializedProperty _type;
        SerializedProperty _range;
        SerializedProperty _color;
        SerializedProperty _intensity;
        SerializedProperty _innerAngle;
        SerializedProperty _outerAngle;
        SerializedProperty _shadowmask;
        SerializedProperty _specularOnlyShadowmask;
        SerializedProperty _destroy;






        void OnEnable()
        {
            _type = serializedObject.FindProperty(nameof(CBIRPLight.lightType));
            _range = serializedObject.FindProperty(nameof(CBIRPLight.range));
            _color = serializedObject.FindProperty(nameof(CBIRPLight.color));
            _intensity = serializedObject.FindProperty(nameof(CBIRPLight.intensity));
            _innerAngle = serializedObject.FindProperty(nameof(CBIRPLight.innerAnglePercent));
            _outerAngle = serializedObject.FindProperty(nameof(CBIRPLight.outerAngle));
            _shadowmask = serializedObject.FindProperty(nameof(CBIRPLight.shadowMask));
            _specularOnlyShadowmask = serializedObject.FindProperty(nameof(CBIRPLight.specularOnlyShadowmask));
            _destroy = serializedObject.FindProperty(nameof(CBIRPLight.destroyComponent));




        }

        public override void OnInspectorGUI()
        {
            if (UdonSharpGUI.DrawDefaultUdonSharpBehaviourHeader(target)) return;

            //base.OnInspectorGUI();

            EditorGUI.BeginChangeCheck();

            EditorGUILayout.PropertyField(_type);
            if (_type.intValue == (int)LightType.Spot)
            {
                EditorGUILayout.PropertyField(_innerAngle);
                EditorGUILayout.PropertyField(_outerAngle);
            }
            EditorGUILayout.PropertyField(_range);
            EditorGUILayout.PropertyField(_color);
            EditorGUILayout.PropertyField(_intensity);
            EditorGUILayout.Space();
            EditorGUILayout.PropertyField(_shadowmask);
            EditorGUILayout.PropertyField(_specularOnlyShadowmask);
            EditorGUILayout.PropertyField(_destroy);




            if (EditorGUI.EndChangeCheck())
            {
                serializedObject.ApplyModifiedProperties();
            }


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
                bakeryLight.projMode = l.lightType == LightType.Point ?
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