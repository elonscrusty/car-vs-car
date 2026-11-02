// Writes the Hornet game files (car 4, twin gatling guns built in). One .obj per part, the safe way to import.
//   obj/Hornet__<Part>.obj       the car without guns, plus the Hood Twins guns (the main look)
//   obj/HornetNose__<Part>.obj   gun parts only: skin "Nose Guns"
//   obj/HornetFender__<Part>.obj gun parts only: skin "Fender Pods"
//   obj/Hornet.obj               the main look in one file (backup if multi-select is awkward)
// Run: node export.js   (no packages needed). Flat faces: every triangle carries its own normal (faceted look).
const fs = require("fs");
const path = require("path");
global.window = {};
require("./hornet-gen.js");

// colour key -> part name (names CarSkin, ToyCars.kartPaint and the Studio mover already know)
const BASE = {
	body: "Body", racing: "Racing", acc: "Accent", glass: "Glass", chrome: "Chrome", chrome2: "Steel", dark: "Dark",
	belt: "Dark", trim: "Trim", plate: "Plate", lamp: "Headlights", glow: "Glow", tail: "Taillights",
};
// a wheel's keys are "FL:tire"; the tyre turns as WheelFL, the rim pieces ride on it (CarSkin: Rim<...>FL)
const WHEEL = { tire: "Wheel", acc: "Rim", chrome: "RimChrome", chrome2: "RimChrome", dark: "RimDark" };
// the gun set ("W:" keys) and the spinning barrels ("GL:" / "GR:" keys), by colour
const GUNMAT = {
	barrel: "Gunmetal", barrel2: "Steel", chrome: "Chrome", chrome2: "Steel2", trim: "Trim", dark: "Dark",
	acc: "Brass", lamp: "Lamp",
};
const MARK = { pivotGL: "PivotL", pivotGR: "PivotR", muzzleGL: "MuzzleL", muzzleGR: "MuzzleR" };

function partsOf(car, base) {
	const parts = {};
	const add = (name, t) => (parts[name] = parts[name] || []).push(...t);
	for (const key in car.bufs) {
		const i = key.indexOf(":");
		const pre = i < 0 ? "" : key.slice(0, i);
		const k = key.slice(i + 1);
		let name;
		if (pre === "") name = BASE[key];
		else if (/^(FL|FR|RL|RR)$/.test(pre)) name = WHEEL[k] + pre;
		else if (pre === "W") name = "Gun" + GUNMAT[k];
		else if (pre === "GL" || pre === "GR") name = "Spin" + pre[1] + GUNMAT[k];
		else if (pre === "M") name = MARK[k];
		if (!name || /undefined/.test(name)) throw new Error("no part for " + key);
		const isBase = pre === "" || /^(FL|FR|RL|RR)$/.test(pre);
		if (isBase === base) add(name, car.bufs[key]);
	}
	return parts;
}

function obj(parts, names, tag) {
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
		lines.push("o " + tag + "__" + name, ...vl, ...nl, ...fl);
		vBase += vl.length;
		nBase += nl.length;
	}
	return lines.join("\n") + "\n";
}

const out = path.join(__dirname, "obj");
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(out, { recursive: true });
const SETS = [["Hornet", 0, "Hood Twins"], ["HornetNose", 1, "Nose Guns"], ["HornetFender", 2, "Fender Pods"]];
let all = {};
for (const [tag, variant, label] of SETS) {
	const car = window.genGatling({ variant, splitWheels: true });
	if (variant === 0) {
		const base = partsOf(car, true);
		for (const n of Object.keys(base).sort()) fs.writeFileSync(path.join(out, `Hornet__${n}.obj`), obj(base, [n], "Hornet"));
		all = { ...base };
	}
	const gun = partsOf(car, false);
	const names = Object.keys(gun).sort();
	for (const n of names) fs.writeFileSync(path.join(out, `${tag}__${n}.obj`), obj(gun, [n], tag));
	let tris = 0;
	for (const n of names) tris += gun[n].length / 9;
	console.log(label, ":", names.length, "gun parts,", tris, "triangles");
	if (variant === 0) {
		Object.assign(all, gun);
		const every = Object.keys(all).sort();
		fs.writeFileSync(path.join(out, "Hornet.obj"), obj(all, every, "Hornet"));
		let t = 0;
		for (const n of every) t += all[n].length / 9;
		console.log("main look:", every.length, "parts,", t, "triangles:", every.join(" "));
	}
}
