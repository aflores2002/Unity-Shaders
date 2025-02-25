Shader "Unlit/Shader-2"
{
    Properties
    {
        _Image1 ("Image 1", 2D) = "white" {} // first image in the swirl transition
        _Image2 ("Image 2", 2D) = "white" {} // second image in the swirl transition
        _SwirlSpeed ("Swirl Speed", Range(0.1, 2.0)) = 0.25 // controls how fast the swirl animation plays
        _SwirlStrength ("Swirl Strength", Range(1.0, 30.0)) = 10.0 // controls how tight the swirl appears
        _SwirlRadiusMin ("Swirl Inner Radius", Range(0.0, 1.0)) = 0.1 // defines where swirl effect begins from center
        _SwirlRadiusMax ("Swirl Outer Radius", Range(0.0, 2.0)) = 1.0 // defines where swirl effect ends from center
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
            // custom properties for controlling swirl transition
            float _SwirlSpeed;
            float _SwirlStrength;
            float _SwirlRadiusMin;
            float _SwirlRadiusMax;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _Image1);
                return o;
            }

            // applies a radial swirl effect to uv coordinates based on distance from center
            // strength controls the amount of twist, direction determines clockwise/counterclockwise
            float2 applySwirlEffect(float2 uv, float2 center, float strength, float direction)
            {
                float2 dir = uv - center;
                float dist = length(dir);

                // calculate how much swirl to apply based on distance from center
                float normalizedDist = smoothstep(_SwirlRadiusMin, _SwirlRadiusMax, dist);

                // convert to polar coordinates for rotation
                float angle = atan2(dir.y, dir.x);

                // apply directional twist that falls off with distance
                float twistAmount = strength * direction * normalizedDist;
                angle += twistAmount;

                // convert back to uv space
                float x = cos(angle) * dist;
                float y = sin(angle) * dist;

                return center + float2(x, y);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // center point for swirl effect
                float2 center = float2(0.5, 0.5);

                // setup timing for alternating right/left swirl cycles
                float time = _Time.y * _SwirlSpeed;
                float fullCycleDuration = 6.0; // complete right-to-left transition cycle
                float halfCycleDuration = 3.0; // single direction swirl duration

                float cycle = fmod(time, fullCycleDuration);
                float direction, swirlFactor, blendFactor;

                // handle right swirl phase (first half of cycle)
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
                        float fadeProgress = (cycle - (halfCycleDuration / 4.0)) / (halfCycleDuration / 2.0);
                        blendFactor = smoothstep(0.0, 1.0, fadeProgress);
                    }
                    else {
                        // last quarter -> keep image 2 visible
                        blendFactor = 1.0;
                    }
                }
                // handle left swirl phase
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

                // calculate final swirl intensity
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