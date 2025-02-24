Shader "Unlit/Shader3"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _GridSize ("Grid Size", Int) = 4
        _Speed ("Animation Speed", Range(0.1, 10.0)) = 1.0
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

            // determines if a grid cell is red-striped
            // based on checkerboard pattern (row + col) % 2
            bool IsRedStripedCell(int2 gridCoord)
            {
                return (gridCoord.x + gridCoord.y) % 2 == 0;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // animation timing
                float totalCycleTime = 4.0; // 4 phases
                float timeInCycle = fmod(_Time.y * _Speed, totalCycleTime);
                int currentPhase = floor(timeInCycle);
                float phaseProgress = frac(timeInCycle);

                // calculate grid coordinates
                float2 gridUV = i.uv * _GridSize;
                int2 gridCoord = int2(floor(gridUV));
                float2 cellUV = frac(gridUV);

                // determine if this cell has red stripes
                bool isRedStripedCell = IsRedStripedCell(gridCoord);

                // initialize UV offsets for both red and green images
                float2 redOffset = float2(0, 0);
                float2 greenOffset = float2(0, 0);

                // apply the appropriate offsets based on the current phase
                if (currentPhase == 0) {
                    // phase 1: Red shifts left, Green shifts right
                    float t = phaseProgress;
                    redOffset = float2(-t, 0) / _GridSize;
                    greenOffset = float2(t, 0) / _GridSize;
                }
                else if (currentPhase == 1) {
                    // phase 2: Red shifts down, Green shifts up
                    redOffset = float2(-1, -phaseProgress) / _GridSize;
                    greenOffset = float2(1, phaseProgress) / _GridSize;
                }
                else if (currentPhase == 2) {
                    // phase 3: Red shifts right, Green shifts left
                    float t = phaseProgress;
                    redOffset = float2(-1 + t, -1) / _GridSize;
                    greenOffset = float2(1 - t, 1) / _GridSize;
                }
                else if (currentPhase == 3) {
                    // final phase: Both converge to center
                    float t = phaseProgress;
                    redOffset = float2(0, -1 + t) / _GridSize;
                    greenOffset = float2(0, 1 - t) / _GridSize;
                }

                // sample the texture with the appropriate offset
                // SWAPPED: Red image now shows in green-striped cells, Green image in red-striped cells
                float2 sampleUV = i.uv;
                if (!isRedStripedCell) {  // SWAPPED: Notice the '!' operator
                    sampleUV += redOffset;
                } else {
                    sampleUV += greenOffset;
                }

                // ensure UVs are within [0,1]
                sampleUV = frac(sampleUV);

                // sample the texture
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