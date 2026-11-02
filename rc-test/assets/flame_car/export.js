// Writes the flame car game files: for each look one .obj per part (obj/<look>/<Prefix>__<Part>.obj, the safe way
// to import) and all of them in one <Prefix>.obj. Run: node export.js   (no packages needed)
// Flat faces: every triangle carries its own normal, so Roblox keeps the faceted look.
const fs = require("fs");
const path = require("path");
global.window = {};
require("./flame-car-gen.js");

// variant -> folder, part-name prefix (the Studio mover finds the parts by it), model id in ReplicatedStorage.CarSkins
const LOOKS = [
	{ variant: 0, dir: "charger", prefix: "FlameCharger" },
	{ variant: 1, dir: "dragon", prefix: "FlameDragon" },
	{ variant: 2, dir: "tanker", prefix: "FlameTanker" },
];
// colour key -> part name (the names ToyCars.kartPaint and CarSkin already know where they can)
const STATIC = {
	body: "Body", acc: "Accent", glass: "Glass", chrome: "Chrome", chrome2: "Steel", dark: "Dark", belt: "Dark",
	trim: "Trim", plate: "Plate", lamp: "Headlights", glow: "Glow", tail: "Taillights", tank: "Tank", bone: "Bone",
	flame2: "FlameFire",
};
// a wheel's keys are "FL:tire"; the tyre turns as WheelFL, the rim pieces ride on it (CarSkin: Rim<...>FL)
const WHEEL = { tire: "Wheel", acc: "Rim", chrome: "RimChrome", chrome2: "RimChrome", dark: "RimDark" };

function obj(prefix, parts, names) {
	const lines = [];
	let vBase = 0, nBase = 0;
	for (const name of names) {
		const t = parts[name];
		const vs = new Map(), ns = new Map(), vl = [], nl = [], fl = [];
		const vi = (a) => {
			const k = a.map((x) => x.toFixed(4)).join(" ");
			if (!vs.has(k)) { vs.set(k, vl.length + 1); vl.push("v " + k); }
			return vs.get(k);
		};
		const ni = (a) => {
			const k = a.map((x) => x.toFixed(4)).join(" ");
			if (!ns.has(k)) { ns.set(k, nl.length + 1); nl.push("vn " + k); }
			return ns.get(k);
		};
		for (let i = 0; i < t.length; i += 9) {
			const A = t.slice(i, i + 3), B = t.slice(i + 3, i + 6), C = t.slice(i + 6, i + 9);
			const u = [B[0] - A[0], B[1] - A[1], B[2] - A[2]], v = [C[0] - A[0], C[1] - A[1], C[2] - A[2]];
			let n = [u[1] * v[2] - u[2] * v[1], u[2] * v[0] - u[0] * v[2], u[0] * v[1] - u[1] * v[0]];
			const l = Math.hypot(...n);
			if (l < 1e-9) continue; // a sliver: nothing to draw
			n = n.map((x) => x / l);
			const ids = [vi(A), vi(B), vi(C)];
			if (ids[0] === ids[1] || ids[1] === ids[2] || ids[0] === ids[2]) continue;
			const nn = ni(n);
			fl.push("f " + ids.map((x) => `${x + vBase}//${nn + nBase}`).join(" "));
		}
		lines.push(`o ${prefix}__${name}`, ...vl, ...nl, ...fl);
		vBase += vl.length;
		nBase += nl.length;
	}
	return lines.join("\n") + "\n";
}

for (const look of LOOKS) {
	const car = window.genFlameCar({ variant: look.variant, splitWheels: true });
	const parts = {};
	for (const key in car.bufs) {
		const [a, b] = key.split(":");
		const name = b ? WHEEL[b] + a : STATIC[key];
		if (!name) throw new Error("no part for " + key);
		(parts[name] = parts[name] || []).push(...car.bufs[key]);
	}
	const out = path.join(__dirname, "obj", look.dir);
	fs.mkdirSync(out, { recursive: true });
	const names = Object.keys(parts).sort();
	for (const n of names) fs.writeFileSync(path.join(out, `${look.prefix}__${n}.obj`), obj(look.prefix, parts, [n]));
	fs.writeFileSync(path.join(out, `${look.prefix}.obj`), obj(look.prefix, parts, names));
	let tris = 0;
	for (const n of names) tris += parts[n].length / 9;
	console.log(look.dir, names.length, "parts,", tris, "triangles:", names.join(" "));
}
