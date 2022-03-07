/*
	References:

	https://github.com/Unity-Technologies/Graphics/blob/1c44c48bf0384aa01cbf1487e39d7ae206638629/com.unity.render-pipelines.universal/Shaders/Utils/ScreenSpaceAmbientOcclusion.shader
	https://github.com/Unity-Technologies/Graphics/blob/1c44c48bf0384aa01cbf1487e39d7ae206638629/com.unity.render-pipelines.universal/ShaderLibrary/SSAO.hlsl
*/

// Material keywords.
#pragma shader_feature EDGE_DEBUG_ON
#pragma shader_feature EDGE_BLEND_MULT EDGE_BLEND_BURN EDGE_BLEND_OVERLAY EDGE_BLEND_ADD

// URP keywords.
#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// #define SCREEN_PARAMS GetScaledScreenParams()
// #define SAMPLE_BASEMAP(uv) SAMPLE_TEXTURE2D_X(_BaseMap, sampler_BaseMap, UnityStereoTransformScreenSpaceTex(uv));

// #if defined(USING_STEREO_MATRICES)
// 	#define unity_eyeIndex unity_StereoEyeIndex
// #else
// 	#define unity_eyeIndex 0
// #endif

int _EdgeQuality;
half4 _EdgeColor;
half _EdgeColorFalloff;
half _EdgeCoplanar;
half _EdgeDepth;
half _EdgeDepthFalloff;
half _EdgeNormalFalloff;
half _EdgeSize;

#include "EdgeFunctions.hlsl"

struct Attributes
{
	float4 positionHCS : POSITION;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float4 positionCS : SV_POSITION;
	float2 uv : TEXCOORD0;
	UNITY_VERTEX_OUTPUT_STEREO
};

Varyings vert(Attributes input)
{
	Varyings output;
	UNITY_SETUP_INSTANCE_ID(input);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

	output.positionCS = float4(input.positionHCS.xyz, 1.0);

	#if UNITY_UV_STARTS_AT_TOP
		output.positionCS.y *= -1;
	#endif

	output.uv = input.uv;
	output.uv += 1.0e-6;

	return output;
}

float4 frag(Varyings input) : SV_Target
{
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

	// Sample screen color.
	float4 color = SAMPLE_TEXTURE2D_X(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, input.uv);

	// Get edge values.
	float4 edge = GetEdgeStrength(input.uv, color, 1.0 / _ScreenParams.x * _EdgeSize, _EdgeDepth);
	float4 edgeColor = _EdgeColor;
	half edgeOpacity = _EdgeColor.a * edge.a;

	// Blend screen with edge.
	#if defined(EDGE_DEBUG_ON)
		return float4(edge.r, edge.g, edge.b, 1);
	#elif defined(EDGE_BLEND_BURN)
		color = clamp(1 - (1 - color) / (edgeColor * edgeOpacity + (1.0 - edgeOpacity)), 0, 1);
	#elif defined(EDGE_BLEND_MULT)
		color *= edgeColor * edgeOpacity + (1.0 - edgeOpacity);
	#elif defined(EDGE_BLEND_OVERLAY)
		edgeColor = lerp(0.5, edgeColor, edgeOpacity);
		color = (color > 0.5) * (1 - (1 - 2 * (color - 0.5)) * (1 - edgeColor)) + (color <= 0.5) * ((2 * color) * edgeColor);
	#elif defined(EDGE_BLEND_ADD)
		color += edgeColor * edgeOpacity;
	#endif

	return color;
}