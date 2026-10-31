// Writes the Toxic Hot Rod game files: one .obj per part (obj/ToxicRod__<Part>.obj, the safe way to import)
// and all of them in one ToxicRod.obj. Run: node export.js   (no packages needed)
// Flat faces: every triangle carries its own normal, so Roblox keeps the faceted look.
const fs = require("fs");
const path = require("path");
global.window = {};
require("./toxic-rod-gen.js");
const car = window.genHotRod({ detail: 2, splitWheels: true });

// colour key -> part name (the names ToyCars.kartPaint and CarSkin already know where they can)
const STATIC = {
	body: "Body", acc: "Accent", glass: "Glass", chrome: "Chrome", chrome2: "Steel", dark: "Dark", belt: "Dark",
	trim: "Trim", plate: "Plate", lamp: "Headlights", glow: "Glow", tail: "Taillights",
};
// a wheel's keys are "FL:tire"; the tyre turns as WheelFL, the rim pieces ride on it (CarSkin: Rim<...>FL)
const WHEEL = { tire: "Wheel", acc: "Rim", chrome: "RimChrome", chrome2: "RimChrome", dark: "RimDark" };

const parts = {};
for (const key in car.bufs) {
	const [a, b] = key.split(":");
	const name = b ? WHEEL[b] + a : STATIC[key];
	if (!name) throw new Error("no part for " + key);
	(parts[name] = parts[name] || []).push(...car.bufs[key]);
}

function obj(names) {
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
		lines.push("o ToxicRod__" + name, ...vl, ...nl, ...fl);
		vBase += vl.length;
		nBase += nl.length;
	}
	return lines.join("\n") + "\n";
}

const out = path.join(__dirname, "obj");
fs.mkdirSync(out, { recursive: true });
const names = Object.keys(parts).sort();
for (const n of names) fs.writeFileSync(path.join(out, `ToxicRod__${n}.obj`), obj([n]));
fs.writeFileSync(path.join(out, "ToxicRod.obj"), obj(names));
let tris = 0;
for (const n of names) tris += parts[n].length / 9;
console.log(names.length, "parts,", tris, "triangles:", names.join(" "));
