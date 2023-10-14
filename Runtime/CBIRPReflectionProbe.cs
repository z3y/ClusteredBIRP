#if !COMPILER_UDONSHARP && UNITY_EDITOR
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

namespace z3y
{
    [ExecuteInEditMode]
    public class CBIRPReflectionProbe : MonoBehaviour
    {
        [HideInInspector] public ReflectionProbe probe;

        [HideInInspector] public Vector4 unity_SpecCube0_ProbePosition;
        [HideInInspector] public Vector4 unity_SpecCube0_BoxMin;
        [HideInInspector] public Vector4 unity_SpecCube0_BoxMax;
        [HideInInspector] public Vector4 unity_SpecCube0_HDR;


        [HideInInspector] public int cubeArrayIndex = 0;

        void Start()
        {
            InitailizeData();
            CBIRPManagerEditor.instance.AddProbe(this);
            if (!Application.isPlaying)
            {
                return;
            }

            Destroy(this);

        }

        private void OnEnable()
        {
            if (CBIRPManagerEditor.instance)
            {
                Start();
            }
        }

        private void OnDestroy()
        {
            CBIRPManagerEditor.instance.RemoveProbe(this);
        }

        public Vector4 GetData0()
        {
            var pos = probe.transform.position;
            bool boxProjection = probe.boxProjection;
            return new Vector4(pos.x, pos.y, pos.z, boxProjection ? 1 : 0);
        }
        public void InitailizeData()
        {
            probe = GetComponent<ReflectionProbe>();
        }

        public Vector4 GetData1()
        {
            //var min = probe.bounds.min;
            var min = probe.transform.position + probe.center - (probe.size * 0.5f);

            return new Vector4(min.x, min.y, min.z, cubeArrayIndex);
        }

        public Vector4 GetData2()
        {
            //var max = probe.bounds.max;
            var max = probe.transform.position + probe.center + (probe.size * 0.5f);
            return new Vector4(max.x, max.y, max.z, probe.blendDistance);
        }

        public Vector4 GetData3()
        {
            return probe.textureHDRDecodeValues;
        }

        /*private void UpdateProbeVariables()
        {
            if (!probe)
            {
                probe = GetComponent<ReflectionProbe>();
                return;
            }

            unity_SpecCube0_ProbePosition = GetData0();
            unity_SpecCube0_BoxMin = GetData1();
            unity_SpecCube0_BoxMax = GetData2();
            unity_SpecCube0_HDR = GetData3();

            if (_propertyBlock == null)
            {
                _meshRenderer = GetComponent<MeshRenderer>();
                _propertyBlock = new MaterialPropertyBlock();

                if (_meshRenderer.HasPropertyBlock())
                {
                    _meshRenderer.GetPropertyBlock(_propertyBlock);
                }
            }

            _propertyBlock.SetVector("_Property0", unity_SpecCube0_ProbePosition);
            _propertyBlock.SetVector("_Property1", unity_SpecCube0_BoxMin);
            _propertyBlock.SetVector("_Property2", unity_SpecCube0_BoxMax);
            _propertyBlock.SetVector("_Property3", unity_SpecCube0_HDR);


            _meshRenderer.SetPropertyBlock(_propertyBlock);

        }*/
    }
}
#endif