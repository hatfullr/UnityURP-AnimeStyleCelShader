Shader "Hidden/AnimePostProcessing/EdgeDetection"
{
	SubShader
	{
		Tags
		{
			"RenderType" = "Opaque"
			"RenderPipeline" = "UniversalPipeline"
		}

		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			Name "EdgeDetection"

			HLSLPROGRAM

			#include "EdgeDetection.hlsl"

			#pragma vertex vert
			#pragma fragment frag

			ENDHLSL
		}
	}
}
