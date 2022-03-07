using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AnimeCelShading
{
	internal enum BlendMode
	{
		Mult,
		Burn,
		Overlay,
		Add,
	}

	internal enum Quality
	{
		Low = 1,
		Medium = 2,
		High = 3,
	}

	[Serializable]
	internal class EdgeDetectionSettings
	{
		public bool Visualize;
		[SerializeField] internal Color Color =  new Color(0.3f, 0.3f, 0.3f, 0.8f);
		[SerializeField] internal BlendMode BlendMode = BlendMode.Mult;
		[SerializeField] internal Quality Quality = Quality.Medium;
		[SerializeField] internal float Size = 2f;
		[SerializeField] internal float Depth = 0.03f;
		[SerializeField] internal float CoplanarFalloff = 0.5f;
		[SerializeField] internal float NormalFalloff = 1f;
		[SerializeField] internal float DepthFalloff = 0.5f;
		[SerializeField] internal float ColorFalloff = 1.5f;
	}

	[DisallowMultipleRendererFeature("Edge Detection")]
	[Tooltip("Customizable aesthetic for rendering edges.")]
	internal class EdgeDetection : ScriptableRendererFeature
	{
		[SerializeField, HideInInspector] private Shader _shader;
		[SerializeField] private EdgeDetectionSettings _settings = new();
		private Material _material;
		private PostEdgePass _pass;

		private const string _shaderName = "Hidden/Anime/EdgeDetection";

		public override void Create()
		{
			if (!GetMaterial())
			{
				return;
			}

			if (_pass == null)
			{
				_pass = new(_material);
			}
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			renderer.EnqueuePass(_pass);
		}

		public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
		{
			_pass.ConfigureInput(ScriptableRenderPassInput.Color);
			_pass.Setup(_settings, renderer);
		}

		protected override void Dispose(bool disposing)
		{
			CoreUtils.Destroy(_material);

			_material = null;
			_pass = null;
		}

		public void OnValidate()
		{
			if (_pass != null)
			{
				_pass.UpdateMaterial();
			}
		}

		private bool GetMaterial()
		{
			if (_material != null)
			{
				return true;
			}

			if (_shader == null)
			{
				_shader = Shader.Find(_shaderName);

				if (_shader == null)
				{
					return false;
				}
			}

			_material = CoreUtils.CreateEngineMaterial(_shader);

			return _material != null;
		}
	}

	internal class PostEdgePass : ScriptableRenderPass
	{
		internal PostEdgePass(Material material)
		{
			_material = material;
			renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
		}

		private EdgeDetectionSettings _settings;
		private Material _material;
		private ProfilingSampler _profileSampler = new ProfilingSampler("EDGE_DETECTION");
		private RTHandle _target;
		private BlendMode _blendMode;

		public static string ToString(BlendMode blendMode)
		{
			return $"EDGE_BLEND_{blendMode.ToString().ToUpper()}";
		}

		public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
		{
			if (_target == null)
			{
				return;
			}
			
			ConfigureTarget(_target);
			ConfigureClear(ClearFlag.None, Color.white);
		}

		public override void OnCameraCleanup(CommandBuffer cmd)
		{
			if (cmd == null)
			{
				throw new ArgumentNullException("cmd");
			}
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (_material == null)
			{
				return;
			}
			
			CommandBuffer cmd = CommandBufferPool.Get();

			using (new ProfilingScope(cmd, _profileSampler))
			{
				cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, _material);
			}

			context.ExecuteCommandBuffer(cmd);
			cmd.Clear();

			CommandBufferPool.Release(cmd);
		}

		internal void Setup(EdgeDetectionSettings settings, ScriptableRenderer renderer)
		{
			_settings = settings;
			_target = renderer.cameraColorTargetHandle;

			// Need depthNormal for sampling.
			ConfigureInput(ScriptableRenderPassInput.Normal);

			// Setup material properties.
			UpdateMaterial();
		}

		internal void UpdateMaterial()
		{
			if (_material == null || _settings == null)
			{
				return;
			}

			_material.SetColor("_EdgeColor", _settings.Color);
			_material.SetFloat("_EdgeColorFalloff", _settings.ColorFalloff);
			_material.SetFloat("_EdgeCoplanar", _settings.CoplanarFalloff);
			_material.SetFloat("_EdgeDepth", _settings.Depth);
			_material.SetFloat("_EdgeDepthFalloff", _settings.DepthFalloff);
			_material.SetFloat("_EdgeNormalFalloff", _settings.NormalFalloff);
			_material.SetFloat("_EdgeSize", _settings.Size);
			_material.SetInt("_EdgeQuality", (int)_settings.Quality);

			_material.EnableKeyword(ToString(_settings.BlendMode));
			
			if (_blendMode != _settings.BlendMode)
			{
				_material.DisableKeyword(ToString(_blendMode));

				_blendMode = _settings.BlendMode;
			}
			
			if (_settings.Visualize)
			{
				_material.EnableKeyword("EDGE_DEBUG_ON");
			}
			else
			{
				_material.DisableKeyword("EDGE_DEBUG_ON");
			}
		}
	}
}