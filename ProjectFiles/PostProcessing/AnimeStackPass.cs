using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AnimeCelShading
{
	public class AnimeStackPass : ScriptableRenderPass
	{
		private static readonly int s_depthId = Shader.PropertyToID("_SourceDepth");

		private RTHandle _colorHandle;
		private RTHandle _colorHandleTarget;
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

			RenderingUtils.ReAllocateIfNeeded(ref _colorHandle, descriptor, FilterMode.Bilinear, TextureWrapMode.Clamp, name: "_SourceTex");
		}

		public override void Configure(CommandBuffer cmd, RenderTextureDescriptor descriptor)
		{
			
		}

		public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
		{
			if (_colorHandleTarget == null || _depthHandle == null)
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

			cmd.Blit(_colorHandleTarget, _colorHandle);

			cmd.SetGlobalTexture(_colorHandle.name, _colorHandle.nameID);
			cmd.SetGlobalTexture(s_depthId, _depthHandle.nameID);

			CoreUtils.SetRenderTarget(
				cmd,
				_colorHandleTarget,
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
			_colorHandleTarget = null;
			_depthHandle = null;
		}

		public override void FrameCleanup(CommandBuffer cmd)
		{
			
		}

		public void Setup(RTHandle colorHandle, RTHandle depthHandle)
		{
			_colorHandleTarget = colorHandle;
			_depthHandle = depthHandle;
		}

		public void Dispose()
		{
			_colorHandleTarget?.Release();
			_depthHandle?.Release();
			_colorHandle?.Release();
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