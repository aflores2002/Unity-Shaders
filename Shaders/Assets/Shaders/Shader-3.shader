Shader "Unlit/Shader-3"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GridSize ("Grid Size", Int) = 4 // controls the size of the grid pattern (e.g. 4x4 matrix)
        _Speed ("Animation Speed", Range(0.1, 10.0)) = 1.0 // controls how fast the image versions animate
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            // properties for controlling the grid-based split image animation
            int _GridSize;
            float _Speed;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            // determines cells where version 1 of the split image should be visible
            // on a 4x4 grid, this includes cells: (1,2), (1,4), (2,1), (2,3), (3,2), (3,4), (4,1), (4,3)
            bool IsVersionOneCell(int2 gridCoord)
            {
                return (gridCoord.x + gridCoord.y) % 2 == 0;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // calculate timing for the animation sequence where both image versions eventually converge
                float totalCycleTime = 4.0;
                float timeInCycle = fmod(_Time.y * _Speed, totalCycleTime);
                int currentPhase = floor(timeInCycle);
                float phaseProgress = frac(timeInCycle);

                // convert uv coordinates to grid space for pattern visibility
                float2 gridUV = i.uv * _GridSize;
                int2 gridCoord = int2(floor(gridUV));
                float2 cellUV = frac(gridUV);

                // determine if this cell should show version 1 of the split image
                bool isVersionOneCell = IsVersionOneCell(gridCoord);

                // initialize UV offsets for both versions of the split image
                float2 splitV1Offset = float2(0, 0);
                float2 splitV2Offset = float2(0, 0);

                // calculate animation offsets for each phase
                if (currentPhase == 0) {
                    // phase 1: version 1 shifts left while version 2 shifts right
                    float t = phaseProgress;
                    splitV1Offset = float2(-t, 0) / _GridSize;
                    splitV2Offset = float2(t, 0) / _GridSize;
                }
                else if (currentPhase == 1) {
                    // phase 2: version 1 shifts down while version 2 shifts up
                    splitV1Offset = float2(-1, -phaseProgress) / _GridSize;
                    splitV2Offset = float2(1, phaseProgress) / _GridSize;
                }
                else if (currentPhase == 2) {
                    // phase 3: version 1 shifts right while version 2 shifts left
                    float t = phaseProgress;
                    splitV1Offset = float2(-1 + t, -1) / _GridSize;
                    splitV2Offset = float2(1 - t, 1) / _GridSize;
                }
                else if (currentPhase == 3) {
                    // final phase: version 1 shifts up while version 2 shifts down to converge with version 1
                    float t = phaseProgress;
                    splitV1Offset = float2(0, -1 + t) / _GridSize;
                    splitV2Offset = float2(0, 1 - t) / _GridSize;
                }

                // apply the appropriate offset based on which version should be visible in this cell
                float2 sampleUV = i.uv;
                if (!isVersionOneCell) {
                    sampleUV += splitV1Offset;
                } else {
                    sampleUV += splitV2Offset;
                }

                // ensure UVs are within [0,1]
                sampleUV = frac(sampleUV);

                // sample the texture to get the appropriate version of the split image
                fixed4 col = tex2D(_MainTex, sampleUV);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}