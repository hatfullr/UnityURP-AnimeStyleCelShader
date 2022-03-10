using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AnimeCelShading
{
	public enum BlendMode
	{
		Mult,
		Burn,
		Overlay,
		Add,
	}

	public enum Quality
	{
		Low = 1,
		Medium = 2,
		High = 3,
	}

	[Serializable, VolumeComponentMenuForRenderPipeline("Anime/Edge Detection", typeof(UniversalRenderPipeline))]
	[AnimeStackComponent("Edge Detection")]
	public sealed class EdgeDetection : VolumeComponent, IPostProcessComponent, IAnimeStackComponent
	{
		public BoolParameter Visualize = new BoolParameter(false);
		public ColorParameter Color = new ColorParameter(new Color(0.3f, 0.3f, 0.3f, 0.8f));
		public BlendModeParameter BlendMode = new BlendModeParameter(AnimeCelShading.BlendMode.Mult);
		public QualityParameter Quality = new QualityParameter(AnimeCelShading.Quality.Medium);
		public ClampedFloatParameter Size = new ClampedFloatParameter(2f, 0f, 32f);
		public MinFloatParameter Depth = new MinFloatParameter(0.03f, 0f);
		public ClampedFloatParameter CoplanarFalloff = new ClampedFloatParameter(0.5f, 0f, 16f);
		public ClampedFloatParameter NormalFalloff = new ClampedFloatParameter(1f, 0f, 16f);
		public ClampedFloatParameter DepthFalloff = new ClampedFloatParameter(0.5f, 0f, 16f);
		public ClampedFloatParameter ColorFalloff = new ClampedFloatParameter(1.5f, 0f, 16f);

		private BlendMode _blendMode;

		public bool IsActive() => Size.GetValue<float>() > Mathf.Epsilon && Color.GetValue<Color>().a > Mathf.Epsilon;

		public bool IsTileCompatible() => false;

		private static string ToString(BlendMode blendMode)
		{
			return $"EDGE_BLEND_{blendMode.ToString().ToUpper()}";
		}

		public void UpdateMaterial(Material material)
		{
			material.SetColor("_EdgeColor", Color.value);
			material.SetFloat("_EdgeColorFalloff", ColorFalloff.value);
			material.SetFloat("_EdgeCoplanar", CoplanarFalloff.value);
			material.SetFloat("_EdgeDepth", Depth.value);
			material.SetFloat("_EdgeDepthFalloff", DepthFalloff.value);
			material.SetFloat("_EdgeNormalFalloff", NormalFalloff.value);
			material.SetFloat("_EdgeSize", Size.value);
			material.SetInt("_EdgeQuality", (int)Quality.value);

			BlendMode blendMode = BlendMode.value;

			material.EnableKeyword(ToString(blendMode));
			
			if (_blendMode != blendMode)
			{
				material.DisableKeyword(ToString(_blendMode));

				_blendMode = blendMode;
			}
			
			if (Visualize.value)
			{
				material.EnableKeyword("EDGE_DEBUG_ON");
			}
			else
			{
				material.DisableKeyword("EDGE_DEBUG_ON");
			}
		}
	}

	[Serializable]
	public sealed class BlendModeParameter : VolumeParameter<BlendMode>
	{
		public BlendModeParameter(BlendMode value, bool overrideState = false) : base(value, overrideState) { }
	}

	[Serializable]
	public sealed class QualityParameter : VolumeParameter<Quality>
	{
		public QualityParameter(Quality value, bool overrideState = false) : base(value, overrideState) { }
	}
}