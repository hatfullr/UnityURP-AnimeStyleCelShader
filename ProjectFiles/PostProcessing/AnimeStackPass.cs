using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AnimeCelShading
{
	public class AnimeStackPass : ScriptableRenderPass
	{
		private static readonly int s_depthId = Shader.PropertyToID("_SourceDepth");

		private RTHandle _tempColor;
		private RTHandle _colorHandle;
		private RTHandle _depthHandle;

		public AnimeStackPass()
		{
			renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
		}

		public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
		{
			ref CameraData cameraData = ref renderingData.cameraData;

			RenderTextureDescriptor descriptor = cameraData.cameraTargetDescriptor;
			descriptor.depthBufferBits = 0;
			descriptor.msaaSamples = 1;

			RenderingUtils.ReAllocateIfNeeded(ref _tempColor, descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SourceTex");
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor descriptor)
		{

		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (_colorHandle == null || _depthHandle == null)
			{
				return;
			}

			ref CameraData cameraData = ref renderingData.cameraData;
			VolumeStack stack = VolumeManager.instance?.stack;

			if (!cameraData.postProcessEnabled || stack == null)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get("Anime Stack");
			cmd.Clear();

			if (cameraData.xrRendering)
			{
				Blitter.BlitCameraTexture(cmd, _colorHandle, _tempColor, 0f, true);
			}
			else
			{
				cmd.Blit(_colorHandle, _tempColor.nameID);
			}

			cmd.SetGlobalTexture(_tempColor.name, _tempColor.nameID);
			cmd.SetGlobalTexture(s_depthId, _depthHandle.nameID);

			CoreUtils.SetRenderTarget(
				cmd,
				_colorHandle,
				RenderBufferLoadAction.DontCare,
				RenderBufferStoreAction.DontCare,
				ClearFlag.None,
				Color.white
			);

			foreach (ComponentData data in AnimeStackFeature.Components)
			{
				VolumeComponent component = stack.GetComponent(data.Type);

				if (component == null || !component.active || component is not IPostProcessComponent postProcessComponent || !postProcessComponent.IsActive())
				{
					continue;
				}

				using (new ProfilingScope(cmd, data.ProfilingSampler))
				{
					Render(cmd, ref renderingData, component, data);
				}
			}

			context.ExecuteCommandBuffer(cmd);
			CommandBufferPool.Release(cmd);
		}

		public override void OnCameraCleanup(CommandBuffer cmd)
		{
			_colorHandle = null;
			_depthHandle = null;
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			
		}

		public void Setup(RTHandle colorHandle, RTHandle depthHandle)
		{
			_colorHandle = colorHandle;
			_depthHandle = depthHandle;
		}

		public void Dispose()
		{
			_tempColor?.Release();
		}

		private void Render(CommandBuffer cmd, ref RenderingData renderingData, VolumeComponent component, ComponentData data)
		{
			if (data.Material == null)
			{
				return;
			}

			if (component is IAnimeStackComponent animeStackComponent)
			{
				animeStackComponent.UpdateMaterial(data.Material);
			}

			cmd.DrawMesh(RenderingUtils.fullscreenMesh, Matrix4x4.identity, data.Material);
		}
	}
}