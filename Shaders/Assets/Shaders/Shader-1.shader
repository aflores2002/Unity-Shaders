Shader "Unlit/Shader-1"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _ScrollSpeed ("Scroll Speed", Float) = 1.0 // controls scroll speed
        _StaticDensity ("Static Density", Float) = 40 // controls the frequency/size of static noise patterns
        _StaticAmount ("Static Amount", Range(0, 1)) = 0.75 // controls the overall intensity of the static effect
        _StaticRate ("Static Update Rate", Float) = 15.0 // controls how frequently the static pattern updates
        _StaticThreshold ("Static Threshold", Range(0.1, 0.9)) = 0.5 // controls the balance of black/white in static
        _StaticSoftness ("Static Softness", Range(0, 0.2)) = 0.05 // controls how smooth or sharp the static appears
        _GrayScale ("Grayscale Amount", Range(0, 1)) = 0.3 // controls how much the image is desaturated
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
            // make fog work
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
            // custom properties for vintage TV effect
            float _ScrollSpeed;
            float _StaticDensity;
            float _StaticAmount;
            float _StaticRate;
            float _StaticThreshold;
            float _StaticSoftness;
            float _GrayScale;

            // generates a pseudo-random value between 0 and 1 based on 2D coordinates
            float random(float2 st)
            {
                return frac(sin(dot(st.xy, float2(12.9898, 78.233))) * 43758.5453123);
            }

            // creates smooth static noise with adjustable threshold and edge softness
            float smoothNoise(float2 st, float threshold, float softness)
            {
                float noise = random(st);
                return smoothstep(threshold - softness, threshold + softness, noise);
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // create vertical scrolling effect using time
                float scrollOffset = _Time.y * _ScrollSpeed;
                float2 scrolledUV = i.uv;
                scrolledUV.y = frac(scrolledUV.y - scrollOffset); // image moves from the bottom-up

                // sample the scrolling texture
                fixed4 col = tex2D(_MainTex, scrolledUV);

                // convert image to grayscale based on luminance weights
                float luminance = dot(col.rgb, float3(0.299, 0.587, 0.114));
                col.rgb = lerp(col.rgb, float3(luminance, luminance, luminance), _GrayScale);

                // calculate time steps to create flickering static
                float timeStep = floor(_Time.y * _StaticRate) / _StaticRate;

                // generate three layers of noise at different scales
                float staticNoise1 = smoothNoise(i.uv * _StaticDensity + timeStep * 6.3, _StaticThreshold, _StaticSoftness);
                float staticNoise2 = smoothNoise(i.uv * (_StaticDensity * 0.7) + timeStep * 4.7, _StaticThreshold, _StaticSoftness);
                float staticNoise3 = smoothNoise(i.uv * (_StaticDensity * 0.3) + timeStep * 2.1, _StaticThreshold, _StaticSoftness * 2.0);

                // blend noise layers with different weights for more natural looking static
                float combinedNoise = staticNoise1 * 0.4 + staticNoise2 * 0.3 + staticNoise3 * 0.3;

                // reduce static in brighter areas of the image
                float brightness = dot(col.rgb, float3(0.2, 0.7, 0.1));
                float adjustedStaticAmount = _StaticAmount * (1.0 - brightness * 0.3);

                // create grayscale static color
                float3 staticColor = float3(combinedNoise, combinedNoise, combinedNoise);

                // blend original image with static effect
                col.rgb = lerp(col.rgb, staticColor, adjustedStaticAmount);

                // add color variation to the static
                col.rgb = lerp(col.rgb, col.rgb * (0.7 + combinedNoise * 0.3), 0.2);

                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return col;
            }
            ENDCG
        }
    }
}