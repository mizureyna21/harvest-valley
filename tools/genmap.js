// Generator peta "forest farm" untuk node_2d.tscn (dijalankan dari root proyek).
const fs = require("fs");
const FILE = "node_2d.tscn";
let L = fs.readFileSync(FILE, "utf8").split("\n");

// ---------- util tile_map_data ----------
function decodeLayer(name) {
	let node = null;
	for (let i = 0; i < L.length; i++) {
		const m = L[i].match(/^\[node name="([^"]+)" type="TileMapLayer"/);
		if (m) node = m[1];
		if (L[i].startsWith("tile_map_data") && node === name) {
			const b = Buffer.from(L[i].match(/"(.*)"/)[1], "base64");
			const t = [];
			for (let k = 2; k + 12 <= b.length; k += 12)
				t.push({ x: b.readInt16LE(k), y: b.readInt16LE(k + 2), s: b.readUInt16LE(k + 4), ax: b.readUInt16LE(k + 6), ay: b.readUInt16LE(k + 8), alt: b.readUInt16LE(k + 10) });
			return t;
		}
	}
	return [];
}
class Layer {
	constructor() { this.m = new Map(); }
	set(x, y, s, ax, ay) { this.m.set(x + "," + y, { x, y, s, ax, ay, alt: 0 }); }
	get(x, y) { return this.m.get(x + "," + y); }
	del(x, y) { this.m.delete(x + "," + y); }
	encode() {
		const arr = [...this.m.values()];
		const b = Buffer.alloc(2 + arr.length * 12);
		arr.forEach((t, i) => {
			const k = 2 + i * 12;
			b.writeInt16LE(t.x, k); b.writeInt16LE(t.y, k + 2); b.writeUInt16LE(t.s, k + 4);
			b.writeUInt16LE(t.ax, k + 6); b.writeUInt16LE(t.ay, k + 8); b.writeUInt16LE(t.alt, k + 10);
		});
		return b.toString("base64");
	}
}
function writeLayer(name, layer) {
	let node = null;
	for (let i = 0; i < L.length; i++) {
		const m = L[i].match(/^\[node name="([^"]+)" type="TileMapLayer"/);
		if (m) node = m[1];
		if (L[i].startsWith("tile_map_data") && node === name) {
			L[i] = 'tile_map_data = PackedByteArray("' + layer.encode() + '")';
			return;
		}
	}
	throw new Error("layer not found " + name);
}
let seed = 1234;
const rnd = () => { seed = (seed * 1103515245 + 12345) & 0x7fffffff; return seed / 0x7fffffff; };

// ---------- ukuran peta ----------
const W = 72, H = 40;

// ---------- layer ----------
const tanah = new Layer();      // TileSet_riqys: src0 = spring sheet (custom data "tillable")
const building = new Layer();   // TileSet_bhunq: src0 houses.png, src1 spring sheet, src2 Big Shed
const buildingTop = new Layer();
const obstacle = new Layer();   // TileSet_sn0t7: src0 spring sheet (physics pagar), src1 crops.png (kaktus/damage)
const treeBot = new Layer();    // TileSet_sn0t7
const treeTop = new Layer();

// ---------- tanah: rumput di tepi, tanah kering dominan ----------
const DX0 = 3, DX1 = 68, DY0 = 4, DY1 = 36; // kotak tanah kering (termasuk tepi transisi)
for (let y = -1; y <= H; y++) for (let x = -1; x <= W; x++) {
	let t;
	if (x < DX0 || x > DX1 || y < DY0 || y > DY1) {
		const r = rnd();
		t = r < 0.04 ? [1, 6] : r < 0.07 ? [2, 6] : [0, 7]; // rumput (sesekali bunga)
	} else if (y === DY0) t = x === DX0 ? [0, 8] : x === DX1 ? [3, 8] : [1, 8];
	else if (y === DY1) t = x === DX0 ? [0, 10] : x === DX1 ? [3, 10] : [1, 10];
	else if (x === DX0) t = [0, 9];
	else if (x === DX1) t = [3, 9];
	else { const r = rnd(); t = r < 0.12 ? [3, 6] : r < 0.55 ? [2, 9] : [1, 9]; } // tanah polos (tillable)
	tanah.set(x, y, 0, t[0], t[1]);
}

// ---------- jalan setapak (tile tanah gelap, TIDAK tillable) ----------
const pathCells = new Set();
function path(x0, y0, x1, y1) {
	for (let y = Math.min(y0, y1); y <= Math.max(y0, y1); y++)
		for (let x = Math.min(x0, x1); x <= Math.max(x0, x1); x++) {
			const v = (x + y) % 2 === 0 ? [15, 23] : [16, 23];
			tanah.set(x, y, 0, v[0], v[1]);
			pathCells.add(x + "," + y);
		}
}
// jalan vertikal depan rumah dihapus atas permintaan
// jalur horizontal y 26..27 dihapus atas permintaan (diganti tanah biasa)
// jalan vertikal ke gerbang selatan dihapus atas permintaan

// ---------- kolam: air di layer tanah + frame tepi di obstacle ----------
const ponds = [];
function pond(x0, y0, x1, y1) {
	ponds.push([x0, y0, x1, y1]);
	for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
		tanah.set(x, y, 0, 8 + Math.floor(rnd() * 4), 13); // air
		let f = null;
		if (y === y0) f = x === x0 ? [8, 7] : x === x1 ? [10, 7] : [9, 7];
		else if (y === y1) f = x === x0 ? [8, 10] : x === x1 ? [10, 10] : [9, 10];
		else if (x === x0) f = [8, 8 + ((y - y0) % 2)];
		else if (x === x1) f = [10, 8 + ((y - y0) % 2)];
		if (f) obstacle.set(x, y, 0, f[0], f[1]);
	}
}
pond(9, 29, 14, 33);
pond(61, 29, 65, 32);

// ---------- tebing batu di batas atas (layer building, src1 spring sheet) ----------
for (let x = -1; x <= W; x++) for (let r = 0; r < 4; r++)
	building.set(x, r, 1, x % 2 === 0 ? 17 : 18, 18 + r);

// ---------- rumah kayu (houses.png) dipindah dari posisi lama ----------
const HDX = 26, HDY = -5; // lama (29..37, 9..17) -> baru (55..63, 4..12)
for (const t of decodeLayer("building")) if (t.s === 0) building.set(t.x + HDX, t.y + HDY, 0, t.ax, t.ay);
for (const t of decodeLayer("building_top")) if (t.s === 0) buildingTop.set(t.x + HDX, t.y + HDY, 0, t.ax, t.ay);

// ---------- pagar kayu ----------
function vfence(x, y0, y1) {
	for (let y = y0; y <= y1; y++) obstacle.set(x, y, 0, 11, y === y0 ? 14 : y === y1 ? 17 : 15 + ((y - y0) % 2));
}
function hfence(x0, x1, y) { // 2 baris: tiang (row 14) + rel ber-collision (row 15)
	for (let x = x0; x <= x1; x++) {
		const c = x === x0 ? 8 : x === x1 ? 13 : 9 + ((x - x0) % 2);
		obstacle.set(x, y, 0, c, 14);
		obstacle.set(x, y + 1, 0, c, 15);
	}
}
vfence(2, 4, 37);
vfence(69, 4, 37);
hfence(3, 32, 37);   // gerbang di x 33..34 (ujung jalan selatan)
hfence(35, 68, 37);

// ---------- pohon (kelompok kecil, total 29) ----------
const trees = [];
function tree(type, bx, by) {
	trees.push([type, bx, by]);
	const cx = type === "o" ? 3 : 10; // kolom kiri kanopi di atlas
	for (let r = 0; r < 4; r++) for (let c = 0; c < 3; c++)
		treeTop.set(bx - 1 + c, by - 5 + r, 0, cx + c, r);
	// (10,4) di atlas = daun/biji kecil, bukan bagian pohon -> tidak dipakai
	treeBot.set(bx, by - 1, 0, type === "o" ? 4 : 11, 4);
	treeBot.set(bx, by, 0, type === "o" ? 4 : 11, 5); // tile ini yang ber-collision
}
const clusters = [
	[["o", 7, 10], ["p", 10, 9], ["o", 8, 14]],                    // C1 kiri atas
	[["p", 17, 9], ["o", 20, 10], ["p", 23, 9], ["o", 19, 14]],    // C2 atas
	[["o", 5, 21], ["p", 8, 20], ["o", 6, 25]],                    // C3 kiri tengah
	[["p", 24, 21], ["p", 25, 25]],                                // C4 tengah kiri (oak 27,23 dihapus)
	[["o", 31, 9], ["p", 34, 10]],                                 // C5 atas tengah
	[["p", 64, 18], ["o", 66, 21], ["p", 63, 24]],                 // C6 kanan
	[["o", 41, 34], ["p", 44, 35], ["o", 47, 34]],                 // C7 bawah tengah
	[["p", 19, 33], ["o", 22, 35], ["p", 25, 33], ["o", 21, 30]],  // C8 kiri bawah
	[["o", 46, 9], ["p", 49, 10]],                                 // C9 dekat rumah
	[["o", 53, 35], ["p", 56, 34]],                                // C10 kanan bawah
];
clusters.forEach(c => c.forEach(t => tree(...t)));

// ---------- semak ----------
function bigBush(x, y) { // 3x3: baris atas di tree_top, 2 baris bawah ber-collision
	for (let c = 0; c < 3; c++) {
		treeTop.set(x + c, y, 0, 13 + c, 0);
		treeBot.set(x + c, y + 1, 0, 13 + c, 1);
		treeBot.set(x + c, y + 2, 0, 13 + c, 2);
	}
}
function smallBush(x, y) { // 2x2
	treeTop.set(x, y, 0, 13, 3); treeTop.set(x + 1, y, 0, 14, 3);
	treeBot.set(x, y + 1, 0, 13, 4); treeBot.set(x + 1, y + 1, 0, 14, 4);
}
[[13, 17], [29, 30], [50, 28], [37, 5]].forEach(p => bigBush(...p));
[[15, 11], [28, 16], [52, 11], [66, 12], [4, 31]].forEach(p => smallBush(...p));

// ---------- ranting kecil (12, tanpa collision) ----------
const twigs = [[12, 22], [29, 12], [36, 30], [44, 29], [52, 13], [65, 26], [17, 24], [27, 36], [39, 11], [58, 31], [11, 35], [48, 31]];
const twigTiles = [[0, 49], [1, 49], [0, 50], [1, 50], [0, 51], [1, 51]];
twigs.forEach((p, i) => obstacle.set(p[0], p[1], 0, ...twigTiles[i % twigTiles.length]));

// ---------- kaktus (crops.png, custom data "damage" di 13:41) ----------
[[29, 14], [38, 30], [66, 9]].forEach(([x, y]) => {
	obstacle.set(x, y - 1, 1, 13, 40);
	obstacle.set(x, y, 1, 13, 41);
});

// ---------- tulis layer ----------
writeLayer("tanah", tanah);
writeLayer("building", building);
writeLayer("building_top", buildingTop);
writeLayer("obstacle", obstacle);
writeLayer("tree_bot", treeBot);
writeLayer("tree_top", treeTop);

// ---------- physics batang pinus (11:5) di TileSet_sn0t7 source 0 ----------
{
	const s = L.indexOf('[sub_resource type="TileSetAtlasSource" id="TileSetAtlasSource_kdubu"]');
	let i = s + 1;
	while (!L[i].startsWith("[") && L[i] !== "11:5/0 = 0") i++;
	if (L[i] === "11:5/0 = 0" && !L[i + 1].startsWith("11:5/0/physics"))
		L.splice(i + 1, 0, "11:5/0/physics_layer_0/polygon_0/points = PackedVector2Array(-5, -8, 5, -8, 5, 6, -5, 6)");
}

// ---------- collision tambahan: tebing atas + kolam (child StaticBody2D "map") ----------
const tile = v => v * 16;
const shapes = [
	["tebing_atas", [tile(36), tile(2)], [tile(W + 2), tile(4)]],
	...ponds.map((p, i) => {
		const x0 = tile(p[0]) + 4, x1 = tile(p[2] + 1) - 4, y0 = tile(p[1]) + 4, y1 = tile(p[3] + 1) - 6;
		return ["kolam_" + (i + 1), [(x0 + x1) / 2, (y0 + y1) / 2], [x1 - x0, y1 - y0]];
	}),
];
// buang versi lama (kalau generator dijalankan ulang)
for (const [name] of shapes) {
	const a = L.findIndex(l => l.startsWith(`[node name="${name}" type="CollisionShape2D" parent="map"`));
	if (a !== -1) { let b = a + 1; while (b < L.length && !L[b].startsWith("[")) b++; L.splice(a, b - a); }
	const sa = L.findIndex(l => l === `[sub_resource type="RectangleShape2D" id="RectangleShape2D_${name}"]`);
	if (sa !== -1) { let b = sa + 1; while (b < L.length && !L[b].startsWith("[")) b++; L.splice(sa, b - sa); }
}
const firstNode = L.findIndex(l => l.startsWith("[node "));
const subs = [];
for (const [name, , size] of shapes) subs.push(`[sub_resource type="RectangleShape2D" id="RectangleShape2D_${name}"]`, `size = Vector2(${size[0]}, ${size[1]})`, "");
L.splice(firstNode, 0, ...subs);
const anchor = L.findIndex(l => l.startsWith('[node name="batasbawah"'));
let end = anchor + 1; while (!L[end].startsWith("[")) end++;
const nodes = [];
for (const [name, pos] of shapes) nodes.push(`[node name="${name}" type="CollisionShape2D" parent="map"]`, `position = Vector2(${pos[0]}, ${pos[1]})`, `shape = SubResource("RectangleShape2D_${name}")`, "");
L.splice(end, 0, ...nodes);

// ---------- posisi player & musuh ----------
const world = (tx, ty) => [1 + tx * 16 + 8, 17 + ty * 16 + 8];
function setPos(nodeName, parent, pos) {
	const i = L.findIndex(l => l.startsWith(`[node name="${nodeName}"`) && l.includes(`parent="${parent}"`));
	let j = i + 1;
	while (!L[j].startsWith("[") && !L[j].startsWith("position =")) j++;
	const line = `position = Vector2(${pos[0]}, ${pos[1]})`;
	if (L[j].startsWith("position =")) L[j] = line; else L.splice(i + 1, 0, line);
}
// Player: node root di (0,0), kaki (collision) ada di offset (435.8, 311.55)
const spawn = world(60, 14);
setPos("Player", ".", [spawn[0] - 436, spawn[1] - 311.5]);
setPos("enemy", ".", world(14, 23));
setPos("enemy2", ".", world(33, 16));
setPos("enemy3", ".", world(40, 31));
setPos("enemy4", ".", world(61, 25));

fs.writeFileSync(FILE, L.join("\n"));

// ---------- laporan ----------
const blocked = new Set();
for (const t of treeBot.m.values()) blocked.add(t.x + "," + t.y);
console.log("pohon:", trees.length, "ranting:", twigs.length);
// cek area farming: x 38..56, y 14..24 harus tanah polos tillable & bebas halangan
const tillable = new Set(["0:6", "0:7", "3:6", "1:7", "2:7", "1:8", "2:8", "1:9", "2:9", "1:10", "2:10"]);
let bad = 0;
for (let y = 14; y <= 24; y++) for (let x = 38; x <= 56; x++) {
	const t = tanah.get(x, y);
	if (!tillable.has(t.ax + ":" + t.ay) || blocked.has(x + "," + y) || obstacle.get(x, y) || building.get(x, y)) bad++;
}
console.log("area farming 19x11, sel tidak bisa dicangkul:", bad);
