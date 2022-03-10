using System;
using System.Reflection;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

namespace AnimeCelShading
{
	[Serializable]
	public class ComponentData
	{
		public ComponentData(Type type, AnimeStackComponent attribute)
		{
			Type = type;
			Attribute = attribute;

			string shaderName = $"Hidden/AnimePostProcessing/{attribute.Name.Replace(" ", "")}";

			ProfilingSampler = new ProfilingSampler(attribute.Name);
			Shader = Shader.Find(shaderName);

			if (Shader == null)
			{
				Debug.LogWarning($"Missing shader '{shaderName}' for anime post-processing effect: {attribute.Name}");
			}
			else
			{
				Material = CoreUtils.CreateEngineMaterial(Shader);
			}
		}

		public Type Type;
		public AnimeStackComponent Attribute;
		public ProfilingSampler ProfilingSampler;
		public Shader Shader;
		public Material Material;
	}

	[DisallowMultipleRendererFeature("Anime Stack")]
	[Tooltip("Customizable aesthetic for rendering edges.")]
	public class AnimeStackFeature : ScriptableRendererFeature
	{
		public static ComponentData[] Components => s_components;

		private static ComponentData[] s_components;

		private AnimeStackPass _pass;

		public override void Create()
		{
			_pass = new();
		}

		public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
		{
			if (_pass == null)
			{
				return;
			}

			LoadStack();

			_pass.ConfigureInput(ScriptableRenderPassInput.Color | ScriptableRenderPassInput.Depth | ScriptableRenderPassInput.Normal);

			renderer.EnqueuePass(_pass);
		}

		public override void SetupRenderPasses(ScriptableRenderer renderer, in RenderingData renderingData)
		{
			_pass?.Setup(renderer.cameraColorTargetHandle, renderer.cameraDepthTargetHandle);
		}

		protected override void Dispose(bool disposing)
		{
			_pass?.Dispose();
		}

		private static void LoadStack()
		{
			// Check already loaded.
			if (s_components != null)
			{
				return;
			}

			List<ComponentData> components = new();

			// Load from current assembly.
			Assembly assembly = Assembly.GetExecutingAssembly();

			foreach (Type type in assembly.GetTypes())
			{
				Attribute attribute = type.GetCustomAttribute(typeof(AnimeStackComponent));

				if (attribute is not AnimeStackComponent stackAttribute)
				{
					continue;
				}

				components.Add(new ComponentData(type, stackAttribute));
			}

			// Convert components.
			s_components = components.ToArray();
		}
	}
}