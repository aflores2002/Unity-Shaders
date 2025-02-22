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

            // Determines if the given grid cell should show the red or green image
            // based on checkerboard pattern (row + col) % 2
            bool IsRedCell(int2 gridCoord)
            {
                return (gridCoord.x + gridCoord.y) % 2 == 0;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // Animation timing
                float totalCycleTime = 4.0; // 4 phases
                float timeInCycle = fmod(_Time.y * _Speed, totalCycleTime);
                int currentPhase = floor(timeInCycle);
                float phaseProgress = frac(timeInCycle);

                // Calculate grid coordinates
                float2 gridUV = i.uv * _GridSize;
                int2 gridCoord = int2(floor(gridUV));
                float2 cellUV = frac(gridUV);

                // Determine if this cell should show the red or green image
                bool isRedCell = IsRedCell(gridCoord);

                // Initialize UV offsets for both red and green images
                float2 redOffset = float2(0, 0);
                float2 greenOffset = float2(0, 0);

                // Apply the appropriate offsets based on the current phase
                // Phase 0: Starting position (both centered)
                // Phase 1: Red shifts left, Green shifts right
                if (currentPhase == 0) {
                    float t = phaseProgress;
                    redOffset = float2(-t, 0) / _GridSize;
                    greenOffset = float2(t, 0) / _GridSize;
                }
                // Phase 2: Red shifts down, Green shifts up
                else if (currentPhase == 1) {
                    redOffset = float2(-1, phaseProgress) / _GridSize;
                    greenOffset = float2(1, -phaseProgress) / _GridSize;
                }
                // Phase 3: Red shifts right, Green shifts left
                else if (currentPhase == 2) {
                    float t = phaseProgress;
                    redOffset = float2(-1 + t, 1) / _GridSize;
                    greenOffset = float2(1 - t, -1) / _GridSize;
                }
                // Final phase: Both converge to center
                else if (currentPhase == 3) {
                    float t = phaseProgress;
                    redOffset = float2(0, 1 - t) / _GridSize;
                    greenOffset = float2(0, -1 + t) / _GridSize;
                }

                // Sample the texture with the appropriate offset based on which image this cell should show
                float2 sampleUV = i.uv;
                if (isRedCell) {
                    sampleUV += redOffset;
                } else {
                    sampleUV += greenOffset;
                }

                // Ensure UVs are within [0,1]
                sampleUV = frac(sampleUV);

                // Sample the texture
                fixed4 col = tex2D(_MainTex, sampleUV);

                // Apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
    Fallback "Diffuse"
}