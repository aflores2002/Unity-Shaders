Shader "Unlit/Shader-2"
{
    Properties
    {
        _Image1 ("Image 1", 2D) = "white" {}
        _Image2 ("Image 2", 2D) = "white" {}
        _SwirlSpeed ("Swirl Speed", Range(0.1, 2.0)) = 0.25
        _SwirlStrength ("Swirl Strength", Range(1.0, 30.0)) = 10.0
        _SwirlRadiusMin ("Swirl Inner Radius", Range(0.0, 1.0)) = 0.1
        _SwirlRadiusMax ("Swirl Outer Radius", Range(0.0, 2.0)) = 1.0
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
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
            };

            sampler2D _Image1;
            sampler2D _Image2;
            float4 _Image1_ST;
            float4 _Image2_ST;
            float _SwirlSpeed;
            float _SwirlStrength;
            float _SwirlRadiusMin;
            float _SwirlRadiusMax;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Image1); // same ST for both textures
                return o;
            }

            float2 applySwirlEffect(float2 uv, float2 center, float strength, float direction)
            {
                float2 dir = uv - center;
                float dist = length(dir);

                // calculate normalized distance within the swirl radius range
                float normalizedDist = smoothstep(_SwirlRadiusMin, _SwirlRadiusMax, dist);

                // calculate the angle to the point
                float angle = atan2(dir.y, dir.x);

                // apply a direction-based twist that's affected by distance
                float twistAmount = strength * direction * normalizedDist;
                angle += twistAmount;

                // convert back to cartesian coordinates
                float x = cos(angle) * dist;
                float y = sin(angle) * dist;

                return center + float2(x, y);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // center point
                float2 center = float2(0.5, 0.5);

                // create a continuous, smooth animation cycle using a sine wave
                // we'll use a 4-second cycle for right swirl and 4-second cycle for left swirl
                float time = _Time.y * _SwirlSpeed;
                float fullCycleDuration = 6.0; // 8 seconds for a full cycle (right + left)
                float halfCycleDuration = 3.0; // 4 seconds for half cycle

                float cycle = fmod(time, fullCycleDuration);
                float direction, swirlFactor, blendFactor;

                // first half cycle (right swirl)
                if (cycle < halfCycleDuration) {
                    direction = 1.0;

                    // create a smooth sine wave for the swirl amount
                    // map from 0-PI for a full up-and-down curve
                    float swirlProgress = sin(3.14159265 * cycle / halfCycleDuration);
                    swirlFactor = swirlProgress;

                    // for fade transition -> starts at max swirl (π/2 or 1/4 of half cycle)
                    // and completes by the time it returns to center (1/2 of half cycle)
                    if (cycle < halfCycleDuration / 4.0) {
                        // first quarter -> swirl up, no fade yet
                        blendFactor = 0.0;
                    }
                    else if (cycle < halfCycleDuration * 3.0 / 4.0) {
                        // second and third quarters -> from max swirl to center, complete fade
                        // this gives us a 2-second fade when using the default timing
                        float fadeProgress = (cycle - (halfCycleDuration / 4.0)) / (halfCycleDuration / 2.0);
                        blendFactor = smoothstep(0.0, 1.0, fadeProgress);
                    }
                    else {
                        // last quarter> - keep image 2 visible
                        blendFactor = 1.0;
                    }
                }
                // second half cycle (left swirl)
                else {
                    float adjustedCycle = cycle - halfCycleDuration;
                    direction = -1.0;

                    // create a smooth sine wave for the swirl amount
                    float swirlProgress = sin(3.14159265 * adjustedCycle / halfCycleDuration);
                    swirlFactor = swirlProgress;

                    // for fade transition -> similar to first half but fade back to image 1
                    if (adjustedCycle < halfCycleDuration / 4.0) {
                        // first quarter -> swirl up, no fade yet
                        blendFactor = 1.0;
                    }
                    else if (adjustedCycle < halfCycleDuration * 3.0 / 4.0) {
                        // second and third quarters -> from max swirl to center, complete fade
                        float fadeProgress = (adjustedCycle - (halfCycleDuration / 4.0)) / (halfCycleDuration / 2.0);
                        blendFactor = 1.0 - smoothstep(0.0, 1.0, fadeProgress);
                    }
                    else {
                        // last quarter -> keep image 1 visible
                        blendFactor = 0.0;
                    }
                }

                // calculate final swirl amount
                float swirlAmount = _SwirlStrength * swirlFactor;

                // apply swirl effect to UV coordinates
                float2 swirlUV = applySwirlEffect(i.uv, center, swirlAmount, direction);

                // sample both textures
                fixed4 col1 = tex2D(_Image1, swirlUV);
                fixed4 col2 = tex2D(_Image2, swirlUV);

                // blend between the two images
                return lerp(col1, col2, blendFactor);
            }
            ENDCG
        }
    }
}