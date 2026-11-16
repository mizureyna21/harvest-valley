// Generator sub-map INTERIOR RUMAH + kasur + kado + pintu rumah untuk node_2d.tscn.
// Jalankan dari root proyek: node tools/genhouse.js   (idempoten: hapus versi lama lalu tulis ulang)
//
// Aset (disalin dari Stardew Valley Content (unpacked), hanya untuk proyek pribadi):
//   map/farmhouse_tiles.png  <- Maps/farmhouse_tiles.png   (dinding, perapian, kasur, TV, dapur, karpet, tanaman)
//   map/walls_and_floors.png <- Maps/walls_and_floors.png  (lantai kayu 2x2 di (0..1, 21..22))
//   map/Giftbox.png          <- LooseSprites/Giftbox.png   (kotak kado, frame Rect2(0, 16, 16, 16))
const fs = require("fs");
const FILE = "node_2d.tscn";
let L = fs.readFileSync(FILE, "utf8").split("\n");

// ---------- tata letak dunia ----------
// Rumah = sub-map ke-3 di scene yang sama, di bawah goa (goa: y 2017..2657). Scene tidak diganti
// supaya FarmingManager, timer hari, tanaman, dan inventory tidak ter-reset.
const ORIGIN = [1, 4017];
const W = 18, H = 14;                                  // ruangan x 0..17, y 0..13 (lantai x 1..16, y 4..11)
const world = (tx, ty) => [ORIGIN[0] + tx * 16 + 8, ORIGIN[1] + ty * 16 + 8];
const roomCenter = [ORIGIN[0] + (W * 16) / 2, ORIGIN[1] + (H * 16) / 2];
// Ruangan lebih kecil dari layar -> batas kamera dibuat 640x360 berpusat di ruangan, sisanya hitam
const HOUSE_LIMITS = [roomCenter[0] - 320, roomCenter[1] - 180, 640, 360];
const FARM_LIMITS = [0, 0, 1151, 657];

const FH = 0, WF = 1; // source id: farmhouse_tiles.png, walls_and_floors.png
const cells = { lantai: [], furnitur: [] };
const tiles = { [FH]: new Map(), [WF]: new Map() }; // "x:y" -> solid?
function put(layer, x, y, src, ax, ay, solid) {
	cells[layer].push([x, y, src, ax, ay]);
	const k = ax + ":" + ay;
	tiles[src].set(k, (tiles[src].get(k) || false) || !!solid);
}

// ---------- lantai, dinding, latar hitam ----------
const isFloor = (x, y) => (x >= 1 && x <= 16 && y >= 4 && y <= 11) || (x >= 7 && x <= 9 && (y === 12 || y === 13));
const wallCol = x => ({ 4: 3, 10: 5, 11: 6, 13: 8, 14: 9 }[x] ?? [2, 4, 7][x % 3]); // 4 = jendela, 10-11 = rak, 13-14 = perapian
for (let y = -6; y <= 20; y++) for (let x = -12; x <= 30; x++) {
	if (isFloor(x, y)) put("lantai", x, y, WF, x % 2, 21 + (y % 2), false);      // lantai kayu
	else if (y >= 0 && y <= 3 && x >= 1 && x <= 16) put("lantai", x, y, FH, wallCol(x), y + 1, true); // dinding kayu
	else if (y === -1 && (x === 13 || x === 14)) put("lantai", x, y, FH, x - 5, 0, true); // cerobong perapian
	else put("lantai", x, y, FH, 0, 0, true);                                    // hitam di luar ruangan
}

// ---------- furnitur ----------
function furniture(x0, y0, ax0, ay0, w, h, solidFromRow) {
	for (let r = 0; r < h; r++) for (let c = 0; c < w; c++)
		put("furnitur", x0 + c, y0 + r, FH, ax0 + c, ay0 + r, r >= solidFromRow);
}
furniture(1, 3, 6, 12, 2, 3, 1);   // TV di kiri atas
furniture(5, 3, 1, 12, 4, 3, 1);   // dapur: lemari, kompor, wastafel
furniture(15, 4, 4, 20, 1, 2, 1);  // tanaman pot di samping perapian
furniture(1, 10, 4, 20, 1, 2, 1);  // tanaman pot kiri bawah
furniture(8, 7, 6, 8, 2, 2, 99);   // karpet oval di tengah (tidak solid)
furniture(15, 8, 8, 7, 2, 4, 1);   // KASUR di kanan bawah, menempel dinding bawah (strip hitam di kaki kasur menyatu dengan dinding)

// ---------- TileSet interior ----------
const ts = [
	'[gd_resource type="TileSet" format=3]', "",
	'[ext_resource type="Texture2D" path="res://map/farmhouse_tiles.png" id="1_fh"]',
	'[ext_resource type="Texture2D" path="res://map/walls_and_floors.png" id="2_wf"]', "",
];
for (const [src, id, tex] of [[FH, "TileSetAtlasSource_fh", "1_fh"], [WF, "TileSetAtlasSource_wf", "2_wf"]]) {
	ts.push(`[sub_resource type="TileSetAtlasSource" id="${id}"]`, `texture = ExtResource("${tex}")`);
	for (const [k, solid] of [...tiles[src].entries()].sort()) {
		ts.push(`${k}/0 = 0`);
		if (solid) ts.push(`${k}/0/physics_layer_0/polygon_0/points = PackedVector2Array(-8, -8, 8, -8, 8, 8, -8, 8)`);
	}
	ts.push("");
}
ts.push("[resource]", "physics_layer_0/collision_layer = 1",
	'sources/0 = SubResource("TileSetAtlasSource_fh")', 'sources/1 = SubResource("TileSetAtlasSource_wf")', "");
fs.writeFileSync("map/rumah_tileset.tres", ts.join("\n"));

function encode(list) {
	const b = Buffer.alloc(2 + list.length * 12);
	list.forEach((c, i) => {
		const k = 2 + i * 12;
		b.writeInt16LE(c[0], k); b.writeInt16LE(c[1], k + 2); b.writeUInt16LE(c[2], k + 4);
		b.writeUInt16LE(c[3], k + 6); b.writeUInt16LE(c[4], k + 8); b.writeUInt16LE(0, k + 10);
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
removeBlock(l => /^\[node name="(Rumah|Kado)"/.test(l) || /parent="Rumah(\/|")/.test(l)
	|| /^\[node name="(MasukRumah|KeluarRumah)"/.test(l) || /parent="Transisi\/(MasukRumah|KeluarRumah)"/.test(l));
removeBlock(l => l.includes('id="house_'));

// ---------- resource ----------
let lastExt = 0; L.forEach((l, i) => { if (l.startsWith("[ext_resource")) lastExt = i; });
L.splice(lastExt + 1, 0,
	'[ext_resource type="TileSet" path="res://map/rumah_tileset.tres" id="house_tileset"]',
	'[ext_resource type="Script" path="res://transition/bed.gd" id="house_bed"]',
	'[ext_resource type="PackedScene" path="res://forage/kado.tscn" id="house_kado"]');
const transitionExt = L.find(l => l.includes('path="res://transition/map_transition.gd"')).match(/ id="([^"]+)"/)[1];
const seedExt = L.find(l => l.includes('path="res://items/parsnip_seed.tres"')).match(/ id="([^"]+)"/)[1];
const firstNode = L.findIndex(l => l.startsWith("[node "));
L.splice(firstNode, 0,
	'[sub_resource type="RectangleShape2D" id="house_shape_bed"]', "size = Vector2(56, 72)", "",
	'[sub_resource type="RectangleShape2D" id="house_shape_door"]', "size = Vector2(32, 16)", "",
	'[sub_resource type="RectangleShape2D" id="house_shape_door_in"]', "size = Vector2(48, 16)", "");

// ---------- titik penting ----------
const v2 = a => `Vector2(${a[0]}, ${a[1]})`;
const r2i = a => `Rect2i(${a.join(", ")})`;
const WAKE = [ORIGIN[0] + 14 * 16 + 4, world(0, 10)[1]];  // kaki player saat spawn & bangun (kiri kasur, 4 px dari collision kasur)
const BED_CENTER = [ORIGIN[0] + 16 * 16, ORIGIN[1] + 10 * 16]; // tengah kasur (x 15..16, y 8..11)
const INSIDE_DOOR = [ORIGIN[0] + 8.5 * 16, world(0, 13)[1]];  // pintu keluar 3 tile (x 7..9, y 13)
const INSIDE_ARRIVE = [INSIDE_DOOR[0], world(0, 10)[1]];      // 3 tile di atas pintu dalam
const FARM_DOOR = [961, 17 + 13 * 16 + 8];                    // tepat di bawah tangga rumah farm (x 59..60, y 13)
const FARM_ARRIVE = [961, 17 + 15 * 16 + 8];                  // 2 tile di depan pintu farm
const KADO = [1 + 62 * 16 + 8, 17 + 14 * 16 + 8];             // kanan depan pintu rumah farm

// ---------- node Rumah (sebelum "obstacle" supaya digambar di bawah player) ----------
const obstacleIdx = L.findIndex(l => l.startsWith('[node name="obstacle"'));
L.splice(obstacleIdx, 0,
	'[node name="Rumah" type="Node2D" parent="."]', `position = ${v2(ORIGIN)}`, "",
	'[node name="lantai" type="TileMapLayer" parent="Rumah"]', `tile_map_data = PackedByteArray("${encode(cells.lantai)}")`, 'tile_set = ExtResource("house_tileset")', "",
	'[node name="furnitur" type="TileMapLayer" parent="Rumah"]', `tile_map_data = PackedByteArray("${encode(cells.furnitur)}")`, 'tile_set = ExtResource("house_tileset")', "",
	'[node name="Kasur" type="Area2D" parent="Rumah"]', `position = ${v2([BED_CENTER[0] - ORIGIN[0], BED_CENTER[1] - ORIGIN[1]])}`,
	'script = ExtResource("house_bed")', `wake_position = ${v2(WAKE)}`, "",
	'[node name="CollisionShape2D" type="CollisionShape2D" parent="Rumah/Kasur"]', 'shape = SubResource("house_shape_bed")', "",
	'[node name="Kado" parent="." instance=ExtResource("house_kado")]', `position = ${v2(KADO)}`,
	`item = ExtResource("${seedExt}")`, "amount = 9", "");

// ---------- pintu rumah (di bawah node Transisi yang sudah ada) ----------
const fadeIdx = L.findIndex(l => l.startsWith('[node name="ScreenFade"'));
L.splice(fadeIdx, 0,
	'[node name="MasukRumah" type="Area2D" parent="Transisi"]', `position = ${v2(FARM_DOOR)}`, "collision_layer = 0", "collision_mask = 1",
	`script = ExtResource("${transitionExt}")`, `target_position = ${v2(INSIDE_ARRIVE)}`, `camera_limits = ${r2i(HOUSE_LIMITS)}`, "",
	'[node name="CollisionShape2D" type="CollisionShape2D" parent="Transisi/MasukRumah"]', 'shape = SubResource("house_shape_door")', "",
	'[node name="KeluarRumah" type="Area2D" parent="Transisi"]', `position = ${v2(INSIDE_DOOR)}`, "collision_layer = 0", "collision_mask = 1",
	`script = ExtResource("${transitionExt}")`, `target_position = ${v2(FARM_ARRIVE)}`, `camera_limits = ${r2i(FARM_LIMITS)}`, "",
	'[node name="CollisionShape2D" type="CollisionShape2D" parent="Transisi/KeluarRumah"]', 'shape = SubResource("house_shape_door_in")', "");

// ---------- spawn awal player di dalam rumah + batas kamera awal ----------
const PLAYER_FEET_OFFSET = [435.805, 311.55];
{
	const i = L.findIndex(l => l.startsWith('[node name="Player"'));
	const j = L.findIndex((l, k) => k > i && l.startsWith("position ="));
	L[j] = `position = ${v2([+(WAKE[0] - PLAYER_FEET_OFFSET[0]).toFixed(3), +(WAKE[1] - PLAYER_FEET_OFFSET[1]).toFixed(3)])}`;
	const c = L.findIndex(l => l.startsWith('[node name="Camera2D" type="Camera2D" parent="Player"'));
	const set = (prop, val) => {
		let k = c + 1;
		while (!L[k].startsWith("[") && !L[k].startsWith(prop + " =")) k++;
		if (L[k].startsWith(prop + " =")) L[k] = `${prop} = ${val}`; else L.splice(c + 1, 0, `${prop} = ${val}`);
	};
	set("limit_left", HOUSE_LIMITS[0]);
	set("limit_top", HOUSE_LIMITS[1]);
	set("limit_right", HOUSE_LIMITS[0] + HOUSE_LIMITS[2]);
	set("limit_bottom", HOUSE_LIMITS[1] + HOUSE_LIMITS[3]);
}

fs.writeFileSync(FILE, L.join("\n"));
console.log("lantai", cells.lantai.length, "furnitur", cells.furnitur.length);
console.log({ WAKE, BED_CENTER, INSIDE_DOOR, INSIDE_ARRIVE, FARM_DOOR, FARM_ARRIVE, KADO, HOUSE_LIMITS });
