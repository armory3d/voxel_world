package arm;

import iron.data.SceneFormat;
import iron.data.MaterialData;
import iron.RenderPath;

class VoxelWorld extends iron.Trait {

	public static var instancedData:kha.arrays.Float32Array;
	public static var voxelImage:kha.Image = null;
	public static inline var size = 64;

	static var p = new Perlin();

	public function new() {
		super();
		notifyOnInit(init);
	}

	function init() {
		var s = size;
		var raw = iron.Scene.active.raw;

		// Voxel rendering shader
		var sh:TShaderData = {
			name: "MyShader",
			contexts: [
				{
					name: "mesh",
					vertex_shader: "vox.vert",
					fragment_shader: "vox.frag",
					compare_mode: "less",
					cull_mode: "clockwise",
					depth_write: true,
					constants: [
						{ name: "WVP", type: "mat4", link: "_worldViewProjectionMatrix" },
						{ name: "s", type: "int" },
						{ name: "s2", type: "int" }
					],
					texture_units: [
						{ name: "tileset" },
						{ name: "volume", link: "_volume" }
					],
					vertex_structure: [
						{ name: "pos", size: 3 },
						{ name: "nor", size: 3 },
						{ name: "tex", size: 2 },
						{ name: "off", size: 3 }
					]
				},
				{
					name: "shadowmap",
					vertex_shader: "voxsm.vert",
					fragment_shader: "voxsm.frag",
					compare_mode: "less",
					cull_mode: "clockwise",
					depth_write: true,
					constants: [
						{ name: "LWVP", type: "mat4", link: "_lampWorldViewProjectionMatrix" },
						{ name: "s", type: "int" },
						{ name: "s2", type: "int" }
					],
					texture_units: [],
					vertex_structure: [
						{ name: "pos", size: 3 },
						{ name: "nor", size: 3 },
						{ name: "tex", size: 2 },
						{ name: "off", size: 3 }
					]
				}
			]
		}

		if (raw.shader_datas == null) raw.shader_datas = [];
		raw.shader_datas.push(sh);

		var md:TMaterialData = {
			name: "MyMaterial",
			shader: "MyShader",
			contexts: [
				{
					name: "mesh",
					bind_textures: [
						{ name: "tileset", file: "tileset.png", min_filter: "point", mag_filter: "point" }
					],
					bind_constants: [
						{ name: "s", int: s },
						{ name: "s2", int: s * s }
					]
				},
				{
					name: "shadowmap",
					bind_constants: [
						{ name: "s", int: s },
						{ name: "s2", int: s * s }
					]
				}
			]
		}
		raw.material_datas.push(md);

		MaterialData.parse(raw.name, md.name, function(res:MaterialData) {
			cast(object, iron.object.MeshObject).materials[0] = res;
			
			// Generate voxel world data
			var num = s * s * s;
			instancedData = new kha.arrays.Float32Array(num * 3);
			for (i in 0...s) {
				for (j in 0...s) {
					for (k in 0...s) {
						// Using perlin here for simplicity, a predefined data file could be loaded instead
						var f = p.OctavePerlin(i / s, j / s, k / s, 5, 0.9, 0.25);

						var tx = 0.0;
						var ty = 0.0;

						if (f > 0.5) {
							var a = Std.random(2) + 1;
							var b = Std.random(3);
							tx = a / 6;
							ty = b / 6;
						}

						var a = i + j * s + k * s * s;
						instancedData[a * 3 + 0] = tx;
						instancedData[a * 3 + 1] = ty;
						instancedData[a * 3 + 2] = 0;
					}
				}
			}

			// Setup instanced rendering
			cast(object, iron.object.MeshObject).data.geom.setupInstanced(instancedData, kha.graphics4.Usage.DynamicUsage);
			instancedData = cast(object, iron.object.MeshObject).data.geom.instancedVB.lock();

			// 3D texture for voxel AO
			var b = haxe.io.Bytes.alloc(s * s * s);
			for (i in 0...b.length) {
				b.set(i, instancedData[i * 3] == 0 ? 0 : 255);
			}
			iron.object.Uniforms.externalTextureLinks.push(textureLink);
			voxelImage = kha.Image.fromBytes3D(b, s, s, s, kha.graphics4.TextureFormat.L8, kha.graphics4.Usage.DynamicUsage);
		});
	}

	public static function textureLink(link:String):kha.Image {
		if (link == "_volume") return voxelImage;
		return null;
	}
}
