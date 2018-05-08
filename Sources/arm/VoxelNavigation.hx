package arm;

import iron.Trait;
import iron.system.Input;
import iron.system.Time;
import iron.object.CameraObject;
import iron.math.Vec4;

class VoxelNavigation extends Trait {

	public static var enabled = true;
	static inline var speed = 5.0;
	var dir = new Vec4();
	var xvec = new Vec4();
	var yvec = new Vec4();
	var easing = true;
	var ease = 1.0;

	var camera:CameraObject;

	var keyboard:Keyboard;
	var gamepad:Gamepad;
	var mouse:Mouse;

	var stepTime = 0.0;
	var soundStep:kha.Sound = null;
	var soundDig:kha.Sound = null;
	var soundDrop:kha.Sound = null;

	var cooldown = 0.0;
	var jump = 0.0;

	public function new(easing = true) {
		super();

		this.easing = easing;
		notifyOnInit(init);
	}

	function init() {
		iron.data.Data.getSound("step.wav", function(sound:kha.Sound) {
			soundStep = sound;
		});

		iron.data.Data.getSound("dig.wav", function(sound:kha.Sound) {
			soundDig = sound;
		});

		iron.data.Data.getSound("drop.wav", function(sound:kha.Sound) {
			soundDrop = sound;
		});

		keyboard = Input.getKeyboard();
		gamepad = Input.getGamepad();
		mouse = Input.getMouse();

		camera = cast object;
		if (camera != null){
			notifyOnUpdate(update);
		}
	}

	function update() {
		if (!enabled || Input.occupied) return;

		if (mouse.started() && !mouse.locked) mouse.lock();
		else if (keyboard.started("esc") && mouse.locked) mouse.unlock();

		var moveForward = keyboard.down(keyUp) || keyboard.down("up");
		var moveBackward = keyboard.down(keyDown) || keyboard.down("down");
		var strafeLeft = keyboard.down(keyLeft) || keyboard.down("left");
		var strafeRight = keyboard.down(keyRight) || keyboard.down("right");
		var strafeUp = keyboard.down(keyStrafeUp);
		var strafeDown = keyboard.down(keyStrafeDown);
		var fast = keyboard.down("shift") ? 2.0 : (keyboard.down("alt") ? 0.5 : 1.0);

		if (gamepad != null) {
			var leftStickY = Math.abs(gamepad.leftStick.y) > 0.05;
			var leftStickX = Math.abs(gamepad.leftStick.x) > 0.05;
			var r1 = gamepad.down("r1") > 0.0;
			var l1 = gamepad.down("l1") > 0.0;
			var rightStickX = Math.abs(gamepad.rightStick.x) > 0.1;
			var rightStickY = Math.abs(gamepad.rightStick.y) > 0.1;

			if (leftStickY || leftStickX || r1 || l1 || rightStickX || rightStickY) {
				dir.set(0, 0, 0);

				if (leftStickY) {
					yvec.setFrom(camera.look());
					yvec.mult(gamepad.leftStick.y);
					dir.add(yvec);
				}
				if (leftStickX) {
					xvec.setFrom(camera.right());
					xvec.mult(gamepad.leftStick.x);
					dir.add(xvec);
				}
				if (r1) dir.addf(0, 0, 1);
				if (l1) dir.addf(0, 0, -1);

				var d = Time.delta * speed * fast;
				move(dir, d);

				if (rightStickX) {
					camera.rotate(Vec4.zAxis(), -gamepad.rightStick.x / 15.0);
				}
				if (rightStickY) {
					camera.rotate(camera.right(), gamepad.rightStick.y / 15.0);
				}
			}
		}
		
		if (moveForward || moveBackward || strafeRight || strafeLeft || strafeUp || strafeDown) {
			if (easing) {
				ease += Time.delta * 15;
				if (ease > 1.0) ease = 1.0;
			}
			else ease = 1.0;
			dir.set(0, 0, 0);
			if (moveForward) dir.addf(camera.look().x, camera.look().y, camera.look().z);
			if (moveBackward) dir.addf(-camera.look().x, -camera.look().y, -camera.look().z);
			if (strafeRight) dir.addf(camera.right().x, camera.right().y, camera.right().z);
			if (strafeLeft) dir.addf(-camera.right().x, -camera.right().y, -camera.right().z);
			if (strafeUp) dir.addf(0, 0, 1);
			if (strafeDown) dir.addf(0, 0, -1);

			stepTime += Time.delta;
			if (stepTime > 0.4 / fast) {
				stepTime = 0;
				iron.system.Audio.play(soundStep);
			}
		}
		else {
			if (easing) {
				ease -= Time.delta * 20.0 * ease;
				if (ease < 0.0) ease = 0.0;
			}
			else ease = 0.0;
		}

		var d = Time.delta * speed * fast * ease;
		if (d > 0.0) move(dir, d);

		if (mouse.locked) {
			camera.rotate(Vec4.zAxis(), -mouse.movementX / 200);
			camera.rotate(camera.right(), -mouse.movementY / 200);
		}

		// Voxels
		// Action
		cooldown -= Time.delta;
		if (mouse.down()) dig();
		else if (mouse.started("right")) drop();

		// Fall down
		var s = VoxelWorld.size;
		var v = camera.transform.world.getLoc();
		var x = Std.int(v.x);
		var y = Std.int(v.y);
		var z = Std.int(v.z);
		if (x >= 0 && x < s &&
		    y >= 0 && y < s &&
		    z >= 2 && z < s + 2) {
			var i = (x + y * s + (z - 2) * s * s) * 3;
			var a = VoxelWorld.instancedData;
			if (a[i] == 0) camera.move(new Vec4(0, 0, -1), 0.15);
		}
		if (x >= 0 && x < s &&
		    y >= 0 && y < s &&
		    z >= s + 2) {
			camera.move(new Vec4(0, 0, -1), 0.15);
		}

		// Jump
		if (jump <= 0 && keyboard.started("space")) {
			if (x >= 0 && x < s &&
		    	y >= 0 && y < s &&
		    	z >= 1 && z < s - 2) {
				var i = (x + y * s + (z + 1) * s * s) * 3;
				var a = VoxelWorld.instancedData;
				var tile1 = a[i];
				i = (x + y * s + (z + 2) * s * s) * 3;
				var tile2 = a[i];
				if (tile1 == 0 && tile2 == 0) {
					jump = 0.4;
				}
			}
			else jump = 0.5; // Always jump when out of volume
		}
		if (jump > 0) {
			camera.move(new Vec4(0,0,1), jump);
			jump -= 0.03;
		}
	}

	function dig() {
		if (cooldown > 0) return;

		var s = VoxelWorld.size;
		var dir = camera.look().normalize();
		var v = camera.transform.world.getLoc();
		v.addf(dir.x * 1.5, dir.y * 1.5, dir.z * 1.5);

		var x = Std.int(v.x);
		var y = Std.int(v.y);
		var z = Std.int(v.z);

		// Dig under player
		var cl = camera.transform.world.getLoc();
		var cx = Std.int(cl.x);
		var cy = Std.int(cl.y);
		var cz = Std.int(cl.z);
		if (x == cx && y == cy && z == cz - 1) z -= 1;

		if (x >= 0 && x < s &&
		    y >= 0 && y < s &&
		    z >= 0 && z < s) {

			var a = VoxelWorld.instancedData;

			var i = (x + y * s + z * s * s) * 3;

			if (a[i] != 0) {
				a[i] = 0;

				var o = iron.Scene.active.getChild("Cube");
				var instancedVB = cast(o, iron.object.MeshObject).data.geom.instancedVB;

				var texi = (x + y * s + z * s * s);
				var vertices = instancedVB.lock();
				vertices.set(i, 0.0);
				#if kha_krom // Voxel ao
				var b = VoxelWorld.voxelImage.lock();
				b.set(texi, 0);
				#end
				
				instancedVB.unlock();
				#if kha_krom // Voxel ao
				VoxelWorld.voxelImage.unlock();
				#end

				iron.system.Audio.play(soundDig);
				cooldown = 0.3;
			}
		}
	}

	function drop() {
		var s = VoxelWorld.size;
		var dir = camera.look().normalize();
		var v = camera.transform.world.getLoc();
		v.addf(dir.x * 1.5, dir.y * 1.5, dir.z * 1.5);

		var x = Std.int(v.x);
		var y = Std.int(v.y);
		var z = Std.int(v.z);

		if (x >= 0 && x < s &&
		    y >= 0 && y < s &&
		    z >= 0 && z < s) {

			var a = VoxelWorld.instancedData;

			var i = (x + y * s + z * s * s) * 3;
			var tile = a[i];

			if (a[i] == 0) {

				var o = iron.Scene.active.getChild("Cube");
				var instancedVB = cast(o, iron.object.MeshObject).data.geom.instancedVB;

				var vertices = instancedVB.lock();

				vertices.set(i, 5.0/6.0);
				vertices.set(i + 1, 0.0/6.0);
			
				instancedVB.unlock();

				iron.system.Audio.play(soundDrop);

				#if kha_krom // Voxel ao
				var texi = (x + y * s + z * s * s);
				var b = VoxelWorld.voxelImage.lock();
				b.set(texi, 255);
				VoxelWorld.voxelImage.unlock();
				#end
			}
		}
	}

	function move(dir:Vec4, d:Float) {
		var s = VoxelWorld.size;
		dir.normalize();
		var v = camera.transform.world.getLoc();
		v.addf(dir.x, dir.y, dir.z);

		var x = Std.int(v.x);
		var y = Std.int(v.y);
		var z = Std.int(v.z);

		if (x >= 0 && x < s &&
		    y >= 0 && y < s &&
		    z >= 1 && z < s - 1) {

			var a = VoxelWorld.instancedData;

			var i = (x + y * s + (z - 1) * s * s) * 3;
			var tile1 = a[i];
			i = (x + y * s + z * s * s) * 3;
			var tile2 = a[i];

			// Obstacle ahead
			if (tile1 != 0 || tile2 != 0) {
				return;
			}
		}

		var vv = new Vec4();
		vv.setFrom(dir);
		vv.z = 0;
		camera.move(vv, d);
	}

	#if arm_azerty
	static inline var keyUp = 'z';
	static inline var keyDown = 's';
	static inline var keyLeft = 'q';
	static inline var keyRight = 'd';
	static inline var keyStrafeUp = 'e';
	static inline var keyStrafeDown = 'a';
	#else
	static inline var keyUp = 'w';
	static inline var keyDown = 's';
	static inline var keyLeft = 'a';
	static inline var keyRight = 'd';
	static inline var keyStrafeUp = 'e';
	static inline var keyStrafeDown = 'q';
	#end
}
