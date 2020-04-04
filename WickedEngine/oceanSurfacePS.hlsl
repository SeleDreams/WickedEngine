#define DISABLE_ALPHATEST
#define DISABLE_DECALS
#define DISABLE_ENVMAPS
#define DISABLE_TRANSPARENT_SHADOWMAP
#include "globals.hlsli"
#include "oceanSurfaceHF.hlsli"
#include "objectHF.hlsli"

#define xGradientMap		texture_0

[earlydepthstencil]
float4 main(PSIn input) : SV_TARGET
{
	float2 gradient = xGradientMap.Sample(sampler_aniso_wrap, input.uv).xy;

	float4 color = float4(xOceanWaterColor, 1);
	float opacity = 1; // keep edge diffuse shading
	float3 V = g_xCamera_CamPos - input.pos3D;
	float dist = length(V);
	V /= dist;
	float emissive = 0;
	Surface surface = CreateSurface(input.pos3D, normalize(float3(gradient.x, xOceanTexelLength * 2, gradient.y)), V, color, 0.001, 1, 0, 0.02);
	Lighting lighting = CreateLighting(0, 0, GetAmbient(surface.N), 0);
	float2 pixel = input.pos.xy;
	float depth = input.pos.z;

	float2 refUV = float2(1, -1)*input.ReflectionMapSamplingPos.xy / input.ReflectionMapSamplingPos.w * 0.5f + 0.5f;
	float2 ScreenCoord = float2(1, -1) * input.pos2D.xy / input.pos2D.w * 0.5f + 0.5f;

	//REFLECTION
	float2 RefTex = float2(1, -1)*input.ReflectionMapSamplingPos.xy / input.ReflectionMapSamplingPos.w / 2.0f + 0.5f;
	float4 reflectiveColor = texture_reflection.SampleLevel(sampler_linear_mirror, RefTex + surface.N.xz * 0.04f, 0);
	float NdotV = abs(dot(surface.N, surface.V));
	float ramp = pow(abs(1.0f / (1.0f + NdotV)), 16);
	reflectiveColor.rgb = lerp(float3(0.38f, 0.45f, 0.56f), reflectiveColor.rgb, ramp); // skycolor hack
	lighting.indirect.specular += reflectiveColor.rgb;

	TiledLighting(pixel, surface, lighting);

	// REFRACTION 
	const float lineardepth = input.pos2D.w;
	const float sampled_lineardepth = texture_lineardepth.SampleLevel(sampler_point_clamp, ScreenCoord.xy + surface.N.xz * 0.04f, 0) * g_xCamera_ZFarP;
	const float depth_difference = max(0, sampled_lineardepth - lineardepth);
	const float3 refractiveColor = texture_refraction.SampleLevel(sampler_linear_mirror, ScreenCoord.xy + surface.N.xz * 0.04f * saturate(0.5 * depth_difference), 0).rgb;

	// WATER FOG
	const float fog_amount = saturate(0.1f * depth_difference);
	surface.albedo = lerp(refractiveColor, color.rgb, fog_amount);
	lighting.direct.diffuse = lerp(1, lighting.direct.diffuse, fog_amount);

	ApplyLighting(surface, lighting, color);

	ApplyFog(dist, color);

	return color;
}

