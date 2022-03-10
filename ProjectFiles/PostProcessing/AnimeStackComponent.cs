using System;
using UnityEngine;

namespace AnimeCelShading
{
	[Serializable]
	[AttributeUsage(AttributeTargets.Class, AllowMultiple = false)]
	public class AnimeStackComponent : Attribute
	{
		public readonly string Name;

		public AnimeStackComponent(string name)
		{
			Name = name;
		}
	}

	public interface IAnimeStackComponent
	{
		public void UpdateMaterial(Material material);
	}
}