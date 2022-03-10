using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AnimeCelShading
{
	public class AnimeStackPass : ScriptableRenderPass
	{
		private static readonly int s_depthId = Shader.PropertyToID("_SourceDepth");

		private RTHandle _sourceColorHandle;
		private RTHandle _sourceDepthHandle;
		private RTHandle _colorHandle;
		private RTHandle _depthHandle;

		public AnimeStackPass()
		{
			renderPassEvent = RenderPassEvent.AfterRenderingTransparents;
		}

		public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
		{
			ref CameraData cameraData = ref renderingData.cameraData;

			RenderTextureDescriptor descriptor = cameraData.cameraTargetDescriptor;
			descriptor.depthBufferBits = 0;

			RenderingUtils.ReAllocateIfNeeded(ref _sourceColorHandle, descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SourceTex");
			RenderingUtils.ReAllocateIfNeeded(ref _sourceDepthHandle, descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SourceDepth");
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

			if (!cameraData.postProcessEnabled)
			{
				return;
			}

			CommandBuffer cmd = CommandBufferPool.Get("Anime Stack");
			VolumeStack stack = VolumeManager.instance.stack;

			cmd.Blit(_depthHandle, _sourceDepthHandle);
			cmd.Blit(_colorHandle, _sourceColorHandle);

			cmd.SetGlobalTexture(_sourceColorHandle.name, _sourceColorHandle.nameID);
			cmd.SetGlobalTexture(_sourceDepthHandle.name, _sourceDepthHandle.nameID);

			CoreUtils.SetRenderTarget(
				cmd,
				_colorHandle,
				RenderBufferLoadAction.DontCare,
				RenderBufferStoreAction.Store,
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
			_colorHandle?.Release();
			_depthHandle?.Release();
			_sourceColorHandle?.Release();
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