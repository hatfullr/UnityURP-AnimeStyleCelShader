Shader "Anime/Lit"
{
	Properties
	{
		// Bases.
		[MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap ("Base Map", 2D) = "white" {}

		// Alpha cutoff.
		[Toggle(_ALPHATEST_ON)] _EnableAlphaTest ("Alpha Cutoff", Float) = 0.0
		_Cutoff ("Cutoff Amount", Range(0.0, 1.0)) = 0.5

		// Lighting settings.
		[Header(Lighting)] [Space]
		
		_ShadeMin ("Shade Min", Range(-1.0, 0.0)) = -1.0
		_ShadeMax ("Shade Max", Range(0.0, 1.0)) = 0.5
		_ShadeFalloff ("Shade Falloff", Float) = 0.5
		_ShadowColor ("Shadow Color", Color) = (0.7, 0.7, 0.8, 1)
		_VertexFalloff ("Vertex Light Falloff", Float) = 0.25

		// Shadow settings.
		[Header(Shadows)] [Space]

		[Toggle] _Receive_Shadows ("Receive Shadows", Float) = 1.0
		_ShadowFalloff ("Shadow Falloff", Float) = 1.5
		[Toggle] _Alternate_Shadows ("Alternate Shadows", Float) = 0.0
	}

	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
			"RenderPipeline" = "UniversalPipeline"
			"UniversalMaterialType" = "Lit"
			"Queue" = "Geometry"
		}
		
		LOD 100

		Pass
		{
			Name "Lit"
			Cull Back
			ZTest LEqual
			ZWrite On
			Blend One Zero

			HLSLPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "AnimeShadePass.hlsl"

			ENDHLSL
		}
		
		Pass
		{
			Name "ShadowCaster"
			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			ZWrite On
			ZTest LEqual
			ColorMask 0
			Cull Back

			HLSLPROGRAM

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

			#pragma multi_compile_instancing
			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

			#pragma vertex ShadowPassVertex
			#pragma fragment ShadowPassFragment

			CBUFFER_START(UnityPerMaterial)
				float4 _BaseMap_ST;
				half4 _BaseColor;
				half _Cutoff;
			CBUFFER_END

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"
			Tags
			{
				"LightMode" = "DepthOnly"
			}

			ZWrite On
			ColorMask R

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
			#pragma shader_feature_local_fragment _ALPHATEST_ON

			#pragma vertex DepthOnlyVertex
			#pragma fragment DepthOnlyFragment

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthOnlyPass.hlsl"

			ENDHLSL
		}

		Pass
		{
			Name "DepthNormalsOnly"
			Tags
			{
				"LightMode" = "DepthNormalsOnly"
			}

			ZWrite On

			HLSLPROGRAM

			#pragma multi_compile_instancing
			#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
			#pragma shader_feature_local_fragment _ALPHATEST_ON

			#pragma vertex DepthNormalsVertex
			#pragma fragment DepthNormalsFragment

			#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/DepthNormalsPass.hlsl"

			ENDHLSL
		}

		Pass
		{
			Name "Meta"
			Tags
			{
				"LightMode" = "Meta"
			}

			Cull Off

			HLSLPROGRAM

			#pragma shader_feature EDITOR_VISUALIZATION

			#pragma vertex UniversalVertexMeta
			#pragma fragment UniversalFragmentMetaUnlit

			#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitInput.hlsl"
			#include "Packages/com.unity.render-pipelines.universal/Shaders/UnlitMetaPass.hlsl"

			ENDHLSL
		}
	}

	Fallback "Hidden/Universal Render Pipeline/Unlit"
}