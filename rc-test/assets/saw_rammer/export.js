// Writes the Saw Rammer game files: obj/SawRammer__<Part>.obj = the car body (one .obj per part, the safe way to import),
// obj/skin_<plow|big|twin>/SawRammer__<skin>_<Part>.obj = the buzzsaw kit of each look. Run: node export.js (no packages needed)
// Flat faces: every triangle carries its own normal, so Roblox keeps the faceted look.
const fs = require("fs");
const path = require("path");
global.window = {};
require("./saw-rammer-gen.js");

// colour key -> part name (the names ToyCars.kartPaint and CarSkin already know where they can)
const STATIC = {
	body: "Body", acc: "Accent", glass: "Glass", chrome: "Chrome", chrome2: "Steel", dark: "Dark", belt: "Dark",
	trim: "Trim", plate: "Plate", lamp: "Headlights", glow: "Glow", tail: "Taillights",
};
// a wheel's keys are "FL:tire"; the tyre turns as WheelFL, the rim pieces ride on it (CarSkin: Rim<...>FL)
const WHEEL = { tire: "Wheel", acc: "Rim", chrome: "RimChrome", chrome2: "RimChrome", dark: "RimDark" };
// the saw kit's keys are "kit:acc" ...; the blades are their own parts so they can spin
const KIT = {
	sawB: "SawBlade", sawH: "SawHub", sawBL: "SawBladeL", sawBR: "SawBladeR", sawHL: "SawHubL", sawHR: "SawHubR",
	acc: "KitAccent", chrome: "KitChrome", chrome2: "KitSteel", trim: "KitTrim", glow: "KitGlow",
};

function partsOf(opt, wantKit) {
	const car = window.genSawRam(Object.assign({ detail: 2, splitWheels: true }, opt));
	const parts = {};
	for (const key in car.bufs) {
		const [a, b] = key.split(":");
		const isKit = a === "kit";
		if (isKit !== wantKit) continue;
		const name = isKit ? KIT[b] : b ? WHEEL[b] + a : STATIC[key];
		if (!name) throw new Error("no part for " + key);
		(parts[name] = parts[name] || []).push(...car.bufs[key]);
	}
	return { parts, spins: car.spins };
}

function obj(parts, names, prefix) {
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
		lines.push("o " + prefix + name, ...vl, ...nl, ...fl);
		vBase += vl.length;
		nBase += nl.length;
	}
	return lines.join("\n") + "\n";
}

const out = path.join(__dirname, "obj");
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
const tris = (p) => Object.values(p).reduce((s, a) => s + a.length / 9, 0);

const body = partsOf({ saw: "none" }, false).parts;
for (const n of Object.keys(body).sort()) fs.writeFileSync(path.join(out, `SawRammer__${n}.obj`), obj(body, [n], "SawRammer__"));
console.log("body:", Object.keys(body).length, "parts,", tris(body), "triangles");

// skin ids: plow = the car (carter's pick), big + twin = skins
for (const skin of ["plow", "big", "twin"]) {
	const { parts, spins } = partsOf({ saw: skin === "big" ? "nose" : skin }, true);
	const dir = path.join(out, "skin_" + skin);
	fs.mkdirSync(dir);
	for (const n of Object.keys(parts).sort()) fs.writeFileSync(path.join(dir, `SawRammer__${skin}_${n}.obj`), obj(parts, [n], `SawRammer__${skin}_`));
	console.log(skin + ":", Object.keys(parts).length, "kit parts,", tris(parts), "triangles; spin axes",
		JSON.stringify(spins.map((s) => ({ blade: s.keys[0], axis: s.axis.map((v) => +v.toFixed(3)) }))));
}
