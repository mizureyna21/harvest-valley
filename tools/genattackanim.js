// Tambah animasi aksi player ke SpriteFrames di node_2d.tscn:
//   attack_* (ayun pedang), hoe_* (mencangkul), water_* (menyiram) — masing-masing front/top/left/right.
// Frame diambil dari char/NEWCHAR.png (grid 10x10, 320 px per frame) yang memang sudah berisi frame-frame ini.
// Jalankan dari root proyek: node tools/genattackanim.js   (idempoten)
const fs = require("fs");
const FILE = "node_2d.tscn";
let L = fs.readFileSync(FILE, "utf8").split("\n");

const ANIMS = {
	// nama: [fps, frame [baris, kolom]...]
	attack_front: [25, [5, 3], [5, 4], [5, 5], [5, 6], [5, 7]],   // 0.2 dtk (< cooldown pedang 0.4)
	attack_top: [25, [5, 8], [5, 9], [6, 0], [6, 1], [6, 2]],
	attack_right: [25, [6, 3], [6, 4], [6, 5], [6, 6], [6, 7]],
	attack_left: [25, [6, 8], [6, 9], [7, 0], [7, 1], [7, 2]],
	hoe_front: [15, [3, 3], [3, 4], [3, 5], [3, 6], [3, 7]],      // ~0.33 dtk
	hoe_top: [15, [3, 8], [3, 9], [4, 0], [4, 1], [4, 2]],
	hoe_right: [15, [4, 3], [4, 4], [4, 5], [4, 6], [4, 7]],
	hoe_left: [15, [4, 8], [4, 9], [5, 0], [5, 1], [5, 2]],
	water_front: [12, [7, 3], [7, 4], [7, 5], [7, 6], [7, 7]],    // ~0.42 dtk
	water_top: [12, [7, 8], [7, 9], [8, 0], [8, 1], [8, 2]],
	water_left: [12, [8, 3], [8, 4], [8, 5], [8, 6], [8, 7]],     // di sheet, gembor urutan kiri dulu baru kanan
	water_right: [12, [8, 8], [8, 9], [9, 0], [9, 1], [9, 2]],
};

// texture NEWCHAR.png dipakai oleh AtlasTexture yang sudah ada
const texId = L.find(l => l.includes('path="res://char/NEWCHAR.png"')).match(/ id="([^"]+)"/)[1];

// ---------- hapus versi lama ----------
for (let i = 0; i < L.length; i++) {
	if (L[i].startsWith('[sub_resource type="AtlasTexture" id="atk_')) {
		let j = i + 1; while (j < L.length && !L[j].startsWith("[")) j++;
		L.splice(i, j - i); i--;
	}
}
const sfIdx = L.findIndex(l => l === '[sub_resource type="SpriteFrames" id="SpriteFrames_sn0t7"]');
let sfEnd = sfIdx + 1; while (!L[sfEnd].startsWith("[")) sfEnd++;
let block = L.slice(sfIdx + 1, sfEnd).join("\n");
// Pecah array "animations = [...]" per objek animasi (hitung kedalaman kurung), buang yang
// attack_/hoe_/water_ lama. Godot mengurutkan ulang animasi saat menyimpan, jadi jangan
// mengandalkan posisi atau regex lintas-animasi.
function splitTopLevel(s) {
	const out = []; let depth = 0, start = 0, inStr = false;
	for (let i = 0; i < s.length; i++) {
		const ch = s[i];
		if (ch === '"' && s[i - 1] !== "\\") inStr = !inStr;
		if (inStr) continue;
		if (ch === "{" || ch === "[") depth++;
		else if (ch === "}" || ch === "]") depth--;
		else if (ch === "," && depth === 0) { out.push(s.slice(start, i).trim()); start = i + 1; }
	}
	const last = s.slice(start).trim();
	if (last) out.push(last);
	return out;
}
const aStart = block.indexOf("animations = [") + "animations = [".length;
const aEnd = block.lastIndexOf("]");
let animList = splitTopLevel(block.slice(aStart, aEnd))
	.filter(a => !/"name": &"(attack|hoe|water)_[a-z]+"/.test(a));
const blockHead = block.slice(0, aStart), blockTail = block.slice(aEnd);

// ---------- AtlasTexture baru ----------
const subs = [];
const animTexts = [];
for (const [name, [fps, ...frames]] of Object.entries(ANIMS)) {
	const entries = frames.map(([r, c]) => {
		const id = `atk_${name}_${r}_${c}`;
		subs.push(`[sub_resource type="AtlasTexture" id="${id}"]`, `atlas = ExtResource("${texId}")`, `region = Rect2(${c * 320}, ${r * 320}, 320, 320)`, "");
		return `{\n"duration": 1.0,\n"texture": SubResource("${id}")\n}`;
	});
	animTexts.push(`{\n"frames": [${entries.join(", ")}],\n"loop": false,\n"name": &"${name}",\n"speed": ${fps}.0\n}`);
}
// susun ulang array: animasi lama (idle/walk) + animasi aksi baru
animList = animList.concat(animTexts);
block = blockHead + animList.join(", ") + blockTail;
L.splice(sfIdx + 1, sfEnd - sfIdx - 1, ...block.split("\n"), "");
const sfNew = L.findIndex(l => l === '[sub_resource type="SpriteFrames" id="SpriteFrames_sn0t7"]');
L.splice(sfNew, 0, ...subs);

fs.writeFileSync(FILE, L.join("\n"));
console.log("animasi ditambah:", Object.keys(ANIMS).join(", "), "texture", texId);
