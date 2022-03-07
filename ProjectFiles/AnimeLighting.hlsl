/*
	References:
	
	https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
	https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl
*/

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/GlobalIllumination.hlsl"

half3 CalculateAnimeShading(Light light, InputData inputData, SurfaceData surfaceData)
{
	// return light.distanceAttenuation;

	half3 result = light.color;

	// Calculate directional attenuation.
	half3 normal = inputData.normalWS;
	half3 lightDir = light.direction;

	half lightDot = saturate(dot(normal, lightDir));
	half dirAttenuation = pow(smoothstep(_ShadeMin, _ShadeMax, lightDot), _ShadeFalloff);

	// return dirAttenuation;

	// Apply surface info.
	result *= surfaceData.albedo;
	result *= surfaceData.occlusion;

	// Apply lighting.
	result *= light.distanceAttenuation;
	result *= dirAttenuation;

	// // Apply shadows.
	#ifdef _RECEIVE_SHADOWS_ON
		#ifdef _ALTERNATE_SHADOWS_ON
			half shadow = 1.0 / (1.0 + light.shadowAttenuation);
		#else
			half shadow = 1.0 - light.shadowAttenuation;
		#endif
		result = lerp(result, result * _ShadowColor, pow(saturate(shadow), _ShadowFalloff));
	#endif

	// Add specular.
	half3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
	half smoothness = exp2(10 * surfaceData.smoothness + 1);

	result += LightingSpecular(attenuatedLightColor, light.direction, inputData.normalWS, inputData.viewDirectionWS, half4(surfaceData.specular, 1), smoothness);

	// Return final color.
	return result;
}

half3 CalculateLights(SurfaceData surfaceData, InputData inputData)
{
	// Light stuff.
	half4 shadowMask = CalculateShadowMask(inputData);
	AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
	Light mainLight = GetMainLight(inputData, shadowMask, aoFactor);

	MixRealtimeAndBakedGI(mainLight, inputData.normalWS, inputData.bakedGI, aoFactor);

	inputData.bakedGI *= surfaceData.albedo;

	// Setup lighting data.
	LightingData lightingData = CreateLightingData(inputData, surfaceData);
	
	// Main light.
	uint meshRenderingLayers = GetMeshRenderingLightLayer();

	if (IsMatchingLightLayer(mainLight.layerMask, meshRenderingLayers))
	{
		lightingData.mainLightColor += CalculateAnimeShading(mainLight, inputData, surfaceData);
	}

	// Extra lights.
	#if defined(_ADDITIONAL_LIGHTS)
		uint pixelLightCount = GetAdditionalLightsCount();

		// #if USE_CLUSTERED_LIGHTING
		// 	for (uint lightIndex = 0; lightIndex < min(_AdditionalLightsDirectionalCount, MAX_VISIBLE_LIGHTS); lightIndex++)
		// 	{
		// 		Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
		// 		if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
		// 		{
		// 			lightingData.additionalLightsColor += CalculateAnimeShading(light, inputData, surfaceData);
		// 		}
		// 	}
		// #endif

		LIGHT_LOOP_BEGIN(pixelLightCount)
			Light light = GetAdditionalLight(lightIndex, inputData, shadowMask, aoFactor);
			if (IsMatchingLightLayer(light.layerMask, meshRenderingLayers))
			{
				lightingData.additionalLightsColor += CalculateAnimeShading(light, inputData, surfaceData);
			}
		LIGHT_LOOP_END
	#endif

	// Vertex lights.
	#if defined(_ADDITIONAL_LIGHTS_VERTEX)
		lightingData.vertexLightingColor += saturate(pow(inputData.vertexLighting, _VertexFalloff)) * surfaceData.albedo;
	#endif

	return CalculateFinalColor(lightingData, surfaceData.alpha);
}