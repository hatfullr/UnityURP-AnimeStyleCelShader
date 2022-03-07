#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareOpaqueTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"

float GetRealDepth(float2 uv)
{
	#if UNITY_REVERSED_Z
		float depth = SampleSceneDepth(uv);
	#else
		float depth = lerp(UNITY_NEAR_CLIP_VALUE, 1, SampleSceneDepth(uv));
	#endif

	return ComputeViewSpacePosition(uv, depth, UNITY_MATRIX_I_P).z;
}

float4 GetEdgeStrength(float2 uv, float3 centerColor, float thickness, float depthC)
{
	float4 sum = 0;

	// Get current pixel.
	float centerDepth = GetRealDepth(uv);
	float3 centerNormal = SampleSceneNormals(uv);

	float size = 3 * _EdgeQuality;
	float sizeH = size * 0.5;
	
	int count = size * size;

	for (int i = 0; i < count; i++) {
		// Get screen position from index.
		float2 _uv = uv + float2(floor(i / size) - sizeH, floor(i % size) - sizeH) * thickness;

		// Get pixel info.
		float depth = GetRealDepth(_uv);
		float3 normal = SampleSceneNormals(_uv);
		float3 color = SampleSceneColor(_uv);

		// Normal differences.
		float nDot = dot(centerNormal, normal);
		float nDelta = _EdgeNormalFalloff > 0.0 ? pow(1.0 - saturate(nDot), _EdgeNormalFalloff) : 0;

		// Depths.
		float dDelta = _EdgeDepthFalloff > 0.0 ? pow(saturate((depth - centerDepth) / depthC), _EdgeDepthFalloff) : 0;

		if (nDot > 0.5) {
			dDelta *= pow(1.0 - saturate(nDot), _EdgeCoplanar);
		}

		// Colors.
		float cDelta = _EdgeColorFalloff > 0.0 ? pow(abs(length(centerColor) - length(color)), _EdgeColorFalloff) : 0;
		
		// Contribute deltas.
		sum.r += dDelta;
		sum.g += nDelta;
		sum.b += cDelta;

		sum.a += dDelta + nDelta + cDelta;
	}

	// Return average sum.
	return saturate(sum / count);
}