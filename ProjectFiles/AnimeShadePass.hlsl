/*
	References:
	
	https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/ComplexLit.shader
	https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl
	https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl
*/

// Material keywords.
#pragma shader_feature _ALPHAPREMULTIPLY_ON
#pragma shader_feature _ALPHATEST_ON
#pragma shader_feature _ALTERNATE_SHADOWS_ON
#pragma shader_feature _RECEIVE_SHADOWS_ON

// URP keywords.
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
#pragma multi_compile _ _CLUSTERED_RENDERING
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
#pragma multi_compile _ _SHADOWS_SOFT
#pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
#pragma multi_compile_fragment _ _LIGHT_COOKIES
#pragma multi_compile_fragment _ _LIGHT_LAYERS
#pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION

// Unity keywords.
#pragma multi_compile _ DIRLIGHTMAP_COMBINED
#pragma multi_compile _ LIGHTMAP_ON
#pragma multi_compile_fog

// GPU instancing.
#pragma instancing_options renderinglayer
#pragma multi_compile _ DOTS_INSTANCING_ON
#pragma multi_compile_instancing

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

int _EdgeQuality;
half _ShadeFalloff;
half _ShadeMax;
half _ShadeMin;
half _ShadowFalloff;
half _VertexFalloff;
half3 _ShadowColor;

CBUFFER_START(UnityPerMaterial)
	half4 _BaseColor;
	float4 _BaseMap_ST;
	half _Cutoff;
CBUFFER_END

#include "AnimeLighting.hlsl"

struct Attributes
{
	float2 dynamicLightmapUV : TEXCOORD2;
	float2 staticLightmapUV : TEXCOORD1;
	float2 uv : TEXCOORD0;
	float3 normalOS : NORMAL;
	float4 positionOS : POSITION;
	float4 tangentOS : TANGENT;

	UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
	float2 uv : TEXCOORD0;
	float3 normalWS : TEXCOORD3;
	float3 viewDirectionWS : TEXCOORD5;
	float4 positionCS : SV_POSITION;
	float3 positionWS : TEXCOORD2;
	half4 additional : TEXCOORD6;

	#ifdef _NORMALMAP
		float4 tangentWS : TEXCOORD4;
	#endif

	#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
		float4 shadowCoord : TEXCOORD7;
	#endif

	DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 8);

	#ifdef DYNAMICLIGHTMAP_ON
		float2 dynamicLightmapUV : TEXCOORD9;
	#endif

	UNITY_VERTEX_INPUT_INSTANCE_ID
	UNITY_VERTEX_OUTPUT_STEREO
};

void InitializeSurfaceData(float2 uv, out SurfaceData surfaceData)
{
	half4 color = SampleAlbedoAlpha(uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)) * _BaseColor;

	surfaceData = (SurfaceData)0;
	
	surfaceData.albedo = color;
	surfaceData.specular = 0.1;
	surfaceData.smoothness = 0.5;
	surfaceData.occlusion = 1;
	surfaceData.alpha = Alpha(color.a, _BaseColor, _Cutoff);
}

void InitializeInputData(Varyings IN, half3 normalTS, out InputData inputData)
{
	inputData = (InputData)0;

	inputData.positionWS = IN.positionWS;
	inputData.viewDirectionWS = SafeNormalize(IN.viewDirectionWS);

	#ifdef _NORMALMAP
		float3 bitangent = IN.tangentWS.w * cross(IN.normalWS.xyz, IN.tangentWS.xyz);
		inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(IN.tangentWS.xyz, bitangent.xyz, IN.normalWS.xyz));
	#else
		inputData.normalWS = IN.normalWS;
	#endif

	#if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
		inputData.shadowCoord = IN.shadowCoord;
	#elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
		inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
	#else
		inputData.shadowCoord = float4(0, 0, 0, 0);
	#endif

	inputData.vertexLighting = IN.additional.yzw;
}

Varyings vert(Attributes IN)
{
	Varyings OUT = (Varyings)0;

	UNITY_SETUP_INSTANCE_ID(IN);
	UNITY_TRANSFER_INSTANCE_ID(IN, OUT);
	UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(OUT);

	// Vertex positions.
	VertexPositionInputs positionInputs = GetVertexPositionInputs(IN.positionOS.xyz);
	OUT.positionCS = positionInputs.positionCS;
	OUT.positionWS = positionInputs.positionWS;

	// UVs.
	OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);

	// View direction.
	OUT.viewDirectionWS = GetWorldSpaceViewDir(positionInputs.positionWS);

	// Normals and tangents.
	VertexNormalInputs normalInputs = GetVertexNormalInputs(IN.normalOS, IN.tangentOS);
	OUT.normalWS =  normalInputs.normalWS;

	#ifdef _NORMALMAP
		real sign = IN.tangentOS.w * GetOddNegativeScale();
		OUT.tangentWS = half4(normalInputs.tangentWS.xyz, sign);
	#endif

	// Vertex lighting and fog.
	half3 vertexLight = VertexLighting(positionInputs.positionWS, normalInputs.normalWS);
	half fogFactor = ComputeFogFactor(positionInputs.positionCS.z);
	
	OUT.additional = half4(fogFactor, vertexLight);

	// Baked and ambient lighting.
	OUTPUT_LIGHTMAP_UV(IN.staticLightmapUV, unity_LightmapST, OUT.staticLightmapUV);

	#ifdef DYNAMICLIGHTMAP_ON
		OUT.dynamicLightmapUV = IN.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
	#endif
	
	OUTPUT_SH(OUT.normalWS.xyz, OUT.vertexSH);

	// Get shadow coord.
	#ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
		OUT.shadowCoord = GetShadowCoord(positionInputs);
	#endif

	return OUT;
}

half4 frag(Varyings IN) : SV_Target
{
	UNITY_SETUP_INSTANCE_ID(IN);
	UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);

	// Surface data.
	SurfaceData surfaceData;
	InitializeSurfaceData(IN.uv, surfaceData);

	// Input data.
	InputData inputData;
	InitializeInputData(IN, surfaceData.normalTS, inputData);

	// Decals.
	#ifdef _DBUFFER
		ApplyDecalToSurfaceData(IN.positionCS, surfaceData, inputData);
	#endif

	// Blend lighting and fog.
	half4 color = half4(CalculateLights(surfaceData, inputData), 1);
	color.rgb = MixFog(color.rgb, IN.additional.x);
	// color.a = OutputAlpha(color.a, );

	// Return final color.
	return color;
}