// Generator sub-map GOA (map/mine.png) + pemicu transisi untuk node_2d.tscn.
// Jalankan dari root proyek: node tools/gencave.js   (idempoten: hapus versi lama lalu tulis ulang)
const fs = require("fs");
const FILE = "node_2d.tscn";
let L = fs.readFileSync(FILE, "utf8").split("\n");

// ---------- tata letak dunia ----------
const CAVE_ORIGIN = [1, 2017];                 // posisi node Goa (farm: map di (1, 17)) -> goa +2000 px ke bawah
const FARM_LIMITS = [0, 0, 1151, 657];         // Rect2i(left, top, w, h) — sama dengan limit kamera lama
const CAVE_LIMITS = [0, 2016, 1151, 657];
const caveWorld = (tx, ty) => [CAVE_ORIGIN[0] + tx * 16 + 8, CAVE_ORIGIN[1] + ty * 16 + 8];
const farmWorld = (tx, ty) => [1 + tx * 16 + 8, 17 + ty * 16 + 8];

let seed = 777;
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };
const pick = a => a[Math.floor(rnd() * a.length)];

// ---------- denah goa: ruangan + koridor (koordinat tile lokal Goa) ----------
const floor = new Set();
const key = (x, y) => x + "," + y;
function room(x0, y0, x1, y1, round = 2) {
	for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
		const dx = Math.min(x - x0, x1 - x), dy = Math.min(y - y0, y1 - y);
		if (dx + dy < round) continue;                       // sudut membulat
		if ((dx === 0 || dy === 0) && rnd() < 0.18) continue; // tepi tidak rata
		floor.add(key(x, y));
	}
}
function corridor(x0, y0, x1, y1) {
	for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) floor.add(key(x, y));
}
room(30, 3, 41, 11);      // R0 ruang masuk (tangga ke farm)
room(6, 6, 22, 18, 3);    // R1 barat
room(50, 5, 66, 16, 3);   // R2 timur (rel tambang)
room(24, 22, 48, 35, 3);  // R3 aula selatan
room(5, 26, 18, 36, 3);   // R4 barat daya
room(55, 24, 67, 35, 3);  // R5 tenggara
corridor(22, 7, 30, 9);   // R0 -> R1
corridor(41, 7, 50, 9);   // R0 -> R2
corridor(34, 11, 37, 22); // R0 -> R3
corridor(18, 29, 24, 31); // R3 -> R4
corridor(48, 28, 55, 30); // R3 -> R5
corridor(60, 16, 62, 24); // R2 -> R5
corridor(34, 3, 36, 8);   // area depan tangga selalu lantai (pintu keluar + spawn)
const isFloor = (x, y) => floor.has(key(x, y));

// ---------- tile mine.png ----------
const FLOOR = [[9, 10], [10, 10], [11, 10], [9, 11], [10, 11], [11, 11], [9, 12], [10, 12], [11, 12], [10, 9]];
const RAIL = [[2, 13], [3, 13]];
const ROCK = [[9, 5], [10, 5], [11, 5], [9, 6], [10, 6], [11, 6], [5, 5], [6, 6]];
const EDGE_BOTTOM = [[9, 7], [10, 7], [11, 7]];   // dinding dengan lantai di bawahnya
const EDGE_BOTTOM_VINE = [[7, 3], [8, 3]];        // varian tanaman rambat
const EDGE_TOP = [[6, 13], [7, 13]];              // dinding dengan lantai di atasnya
const EDGE_RIGHT = [[15, 10], [15, 11]];          // dinding dengan lantai di kirinya
const WALL_LANTERN = [2, 5];                      // lentera menempel di dinding
const LADDER = [[3, 4], [3, 5], [3, 6], [3, 7]];  // tangga keluar ke farm
const DECO = { lantern: [0, 3], skullTop: [0, 1], skullBot: [0, 2], barrel: [13, 10], chest: [13, 14], furnace: [14, 14], basket: [15, 14] };

const solidTiles = new Set();
const allTiles = new Set();
const use = (t, solid) => { allTiles.add(t.join(":")); if (solid) solidTiles.add(t.join(":")); return t; };

const cells = { lantai: [], dinding: [], dekorasi: [] };
const put = (layer, x, y, t, solid = false) => cells[layer].push([x, y, ...use(t, solid)]);

const X0 = -3, X1 = 74, Y0 = -4, Y1 = 43;
const ladderX = 35;
let lanternCounter = 0;
for (let y = Y0; y <= Y1; y++) for (let x = X0; x <= X1; x++) {
	if (isFloor(x, y)) {
		const onRail = y === 12 && x >= 52 && x <= 64;
		put("lantai", x, y, onRail ? RAIL[x % 2] : pick(FLOOR));
		continue;
	}
	// tangga keluar menempel di dinding atas ruang masuk
	if (x === ladderX && y >= -1 && y <= 2) {
		put("lantai", x, y, pick(FLOOR));
		put("dinding", x, y, LADDER[y + 1], true);
		continue;
	}
	const below = isFloor(x, y + 1), above = isFloor(x, y - 1), left = isFloor(x - 1, y), right = isFloor(x + 1, y);
	let t;
	if (below) {
		lanternCounter++;
		t = lanternCounter % 7 === 0 ? WALL_LANTERN : rnd() < 0.1 ? pick(EDGE_BOTTOM_VINE) : pick(EDGE_BOTTOM);
	} else if (above) t = pick(EDGE_TOP);
	else if (left) t = pick(EDGE_RIGHT);
	else t = pick(ROCK);
	// tile tepi punya bagian transparan -> beri lantai di bawahnya
	if (below || above || left || right) put("lantai", x, y, pick(FLOOR));
	put("dinding", x, y, t, true);
}

// ---------- dekorasi (tanpa collision) ----------
const decoAt = (x, y, t) => { if (isFloor(x, y)) put("dekorasi", x, y, t); };
[[31, 4], [40, 4], [7, 8], [21, 8], [8, 17], [51, 7], [65, 7], [26, 24], [46, 24], [26, 34], [46, 34], [7, 28], [17, 35], [57, 26], [66, 34]]
	.forEach(p => decoAt(p[0], p[1], DECO.lantern));
decoAt(30, 26, DECO.skullTop); decoAt(30, 27, DECO.skullBot);
[[20, 16], [21, 17], [7, 35], [66, 26]].forEach(p => decoAt(p[0], p[1], DECO.barrel));
decoAt(61, 34, DECO.chest);
decoAt(65, 15, DECO.furnace);
decoAt(51, 15, DECO.basket);

// ---------- TileSet goa ----------
const tsLines = [
	'[gd_resource type="TileSet" format=3]', "",
	'[ext_resource type="Texture2D" uid="uid://dogvouv0qbw0x" path="res://map/mine.png" id="1_mine"]', "",
	'[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_mine"]',
	'texture = ExtResource("1_mine")',
];
for (const t of [...allTiles].sort()) {
	tsLines.push(`${t}/0 = 0`);
	if (solidTiles.has(t)) tsLines.push(`${t}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)`);
}
tsLines.push("", "[resource]", "physics_layer_0/collision_layer = 1", 'sources/0 = SubResource("TileSetAtlasSource_mine")', "");
fs.writeFileSync("map/mine_tileset.tres", tsLines.join("\n"));

function encode(list) {
	const b = Buffer.alloc(2 + list.length * 12);
	list.forEach((c, i) => {
		const k = 2 + i * 12;
		b.writeInt16LE(c[0], k); b.writeInt16LE(c[1], k + 2); b.writeUInt16LE(0, k + 4);
		b.writeUInt16LE(c[2], k + 6); b.writeUInt16LE(c[3], k + 8); b.writeUInt16LE(0, k + 10);
	});
	return b.toString("base64");
}

// ---------- hapus hasil generator sebelumnya ----------
function removeBlock(pred) {
	for (let i = 0; i < L.length; i++) {
		if (L[i].startsWith("[") && pred(L[i])) {
			let j = i + 1; while (j < L.length && !L[j].startsWith("[")) j++;
			L.splice(i, j - i); i--;
		}
	}
}
removeBlock(l => /^\[node name="(Goa|Transisi|ScreenFade)"/.test(l) || /parent="(Goa|Transisi)(\/|")/.test(l));
removeBlock(l => l.includes('id="cave_'));

// ---------- ext_resource & sub_resource ----------
let lastExt = 0; L.forEach((l, i) => { if (l.startsWith("[ext_resource")) lastExt = i; });
L.splice(lastExt + 1, 0,
	'[ext_resource type="TileSet" path="res://map/mine_tileset.tres" id="cave_tileset"]',
	'[ext_resource type="Script" path="res://transition/map_transition.gd" id="cave_transition"]',
	'[ext_resource type="Script" path="res://transition/screen_fade.gd" id="cave_fade"]');
const firstNode = L.findIndex(l => l.startsWith("[node "));
L.splice(firstNode, 0,
	'[sub_resource type="RectangleShape2D" id="cave_shape_ke_goa"]', "size = Vector2(32, 32)", "",
	'[sub_resource type="RectangleShape2D" id="cave_shape_ke_farm"]', "size = Vector2(48, 16)", "");

// ---------- node goa (sebelum "obstacle" supaya digambar di bawah player) ----------
const v2 = a => `Vector2(${a[0]}, ${a[1]})`;
const r2i = a => `Rect2i(${a.join(", ")})`;
const obstacleIdx = L.findIndex(l => l.startsWith('[node name="obstacle"'));
L.splice(obstacleIdx, 0,
	'[node name="Goa" type="Node2D" parent="."]', `position = ${v2(CAVE_ORIGIN)}`, "",
	'[node name="lantai" type="TileMapLayer" parent="Goa"]', `tile_map_data = PackedByteArray("${encode(cells.lantai)}")`, 'tile_set = ExtResource("cave_tileset")', "",
	'[node name="dinding" type="TileMapLayer" parent="Goa"]', `tile_map_data = PackedByteArray("${encode(cells.dinding)}")`, 'tile_set = ExtResource("cave_tileset")', "",
	'[node name="dekorasi" type="TileMapLayer" parent="Goa"]', `tile_map_data = PackedByteArray("${encode(cells.dekorasi)}")`, 'tile_set = ExtResource("cave_tileset")', "");

// ---------- pemicu transisi + layar fade (di akhir, sebelum [editable]) ----------
const FARM_GATE = [545, 641];                 // celah pagar bawah farm, tile x 33..34, y 38..39
const FARM_RETURN = [545, farmWorld(0, 35)[1]]; // 3 tile di atas celah, di dalam farm
const CAVE_EXIT = caveWorld(ladderX, 3);        // lantai tepat di bawah tangga
const CAVE_SPAWN = caveWorld(ladderX, 6);       // 3 tile di bawah pintu keluar
const editableIdx = L.findIndex(l => l.startsWith("[editable"));
L.splice(editableIdx === -1 ? L.length : editableIdx, 0,
	'[node name="Transisi" type="Node2D" parent="."]', "",
	'[node name="KeGoa" type="Area2D" parent="Transisi"]', `position = ${v2(FARM_GATE)}`, "collision_layer = 0", "collision_mask = 1",
	'script = ExtResource("cave_transition")', `target_position = ${v2(CAVE_SPAWN)}`, `camera_limits = ${r2i(CAVE_LIMITS)}`, "",
	'[node name="CollisionShape2D" type="CollisionShape2D" parent="Transisi/KeGoa"]', 'shape = SubResource("cave_shape_ke_goa")', "",
	'[node name="KeFarm" type="Area2D" parent="Transisi"]', `position = ${v2(CAVE_EXIT)}`, "collision_layer = 0", "collision_mask = 1",
	'script = ExtResource("cave_transition")', `target_position = ${v2(FARM_RETURN)}`, `camera_limits = ${r2i(FARM_LIMITS)}`, "",
	'[node name="CollisionShape2D" type="CollisionShape2D" parent="Transisi/KeFarm"]', 'shape = SubResource("cave_shape_ke_farm")', "",
	'[node name="ScreenFade" type="CanvasLayer" parent="."]', 'script = ExtResource("cave_fade")', "");

// ---------- pindahkan musuh ke goa (node yang sama, hanya posisi) ----------
function setProp(nodeName, prop, value) {
	const i = L.findIndex(l => l.startsWith(`[node name="${nodeName}"`) && l.includes('parent="."'));
	if (i === -1) throw new Error("node " + nodeName);
	let j = i + 1;
	while (j < L.length && !L[j].startsWith("[") && !L[j].startsWith(prop + " =")) j++;
	if (j < L.length && L[j].startsWith(prop + " =")) L[j] = `${prop} = ${value}`;
	else L.splice(i + 1, 0, `${prop} = ${value}`);
}
const enemies = { enemy: [14, 12], enemy2: [58, 10], enemy3: [36, 30], enemy4: [61, 30] };
for (const [name, t] of Object.entries(enemies)) {
	if (!isFloor(t[0], t[1])) throw new Error(name + " tidak di lantai");
	setProp(name, "position", v2(caveWorld(t[0], t[1])));
}
// ghost/bug/fly aslinya collision_mask = 0 (tembus segala). Di level ini diberi mask 1 supaya tertahan
// dinding goa dan tidak melayang keluar dari area goa.
for (const name of ["enemy2", "enemy3", "enemy4"]) setProp(name, "collision_mask", "1");

fs.writeFileSync(FILE, L.join("\n"));
console.log("lantai", cells.lantai.length, "dinding", cells.dinding.length, "dekorasi", cells.dekorasi.length,
	"tile unik", allTiles.size, "solid", solidTiles.size);
console.log("spawn goa", CAVE_SPAWN, "pintu keluar goa", CAVE_EXIT, "pintu farm", FARM_GATE, "kembali ke farm", FARM_RETURN);
