// Writes the mine-layer game files for all 3 cars: obj/<car>/<Prefix>__<Part>.obj (one per part, the safe way to
// import), obj/<car>/<Prefix>.obj (the whole car in one file), and studio_mine_layer.luau (from the template).
// Run: node export.js   (no packages needed). Flat faces: every triangle carries its own normal (faceted look).
const fs = require("fs");
const path = require("path");
global.window = {};
require("./mine-layer-gen.js");

const CARS = [
	{ idx: 0, id: "grave_layer", prefix: "GraveLayer" },
	{ idx: 1, id: "widow_maker", prefix: "WidowMaker" },
	{ idx: 2, id: "rust_hopper", prefix: "RustHopper" },
];
// colour key -> part name (names ToyCars.kartPaint / CarSkin already know where they can)
const STATIC = {
	body: "Body", acc: "Accent", glass: "Glass", chrome: "Chrome", chrome2: "Steel", dark: "Dark", belt: "Dark",
	trim: "Trim", plate: "Plate", lamp: "Headlights", glow: "Glow", tail: "Taillights",
	mine: "Mine", spike: "Spike", blink: "Blink", hinge: "ArmHinge",
};
const ARM = { chrome2: "ArmSteel", acc: "ArmAccent", trim: "ArmTrim" }; // swing with the arm (pivot = ArmHinge)
const LOADED = { mine: "LoadedMine", spike: "LoadedSpike", chrome: "LoadedChrome", blink: "LoadedBlink" }; // the mine in the spoon
// a wheel's keys are "FL:tire"; the tyre turns as WheelFL, the rim pieces ride on it (CarSkin: Rim<...>FL)
const WHEEL = { tire: "Wheel", acc: "Rim", chrome: "RimChrome", chrome2: "RimChrome", dark: "RimDark" };
const WHEELKEY = /^(FL|FR|RL|RR)$/;

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
		lines.push("o " + prefix + "__" + name, ...vl, ...nl, ...fl);
		vBase += vl.length;
		nBase += nl.length;
	}
	return lines.join("\n") + "\n";
}

const rgb = (a) => `Color3.fromRGB(${a.join(", ")})`;
let luaCars = "";
for (const c of CARS) {
	const car = window.genMine({ car: c.idx, splitWheels: true });
	const parts = {};
	for (const key in car.bufs) {
		const bits = key.split(":");
		let name;
		if (bits.length === 1) name = STATIC[key];
		else if (bits[0] === "arm") name = ARM[bits[1]];
		else if (bits[0] === "lm") name = LOADED[bits[1]];
		else if (WHEELKEY.test(bits[0])) name = WHEEL[bits[1]] + bits[0];
		if (!name) throw new Error("no part for " + key);
		(parts[name] = parts[name] || []).push(...car.bufs[key]);
	}
	const dir = path.join(__dirname, "obj", c.id);
	fs.rmSync(dir, { recursive: true, force: true });
	fs.mkdirSync(dir, { recursive: true });
	const names = Object.keys(parts).sort();
	let tris = 0, big = ["", 0];
	for (const n of names) {
		fs.writeFileSync(path.join(dir, `${c.prefix}__${n}.obj`), obj(parts, [n], c.prefix));
		const k = parts[n].length / 9;
		tris += k;
		if (k > big[1]) big = [n, k];
	}
	fs.writeFileSync(path.join(dir, `${c.prefix}.obj`), obj(parts, names, c.prefix));
	console.log(c.id, names.length, "parts,", tris, "triangles, biggest", big[0], big[1]);
	const C = car.COL, N = car.NEON, S = window.MINESPEC[c.idx];
	luaCars += `\t{ id = "${c.id}", prefix = "${c.prefix}", name = "${S.name}", colors = {
		Body = ${rgb(C.body)}, Accent = ${rgb(C.acc)}, Glass = ${rgb(C.glass)}, Chrome = ${rgb(C.chrome)}, Steel = ${rgb(C.chrome2)},
		Dark = ${rgb(C.dark)}, Trim = ${rgb(C.trim)}, Plate = ${rgb(N.plate)}, Headlights = ${rgb(N.lamp)}, Glow = ${rgb(N.glow)},
		Taillights = ${rgb(N.tail)}, Mine = ${rgb(C.mine)}, Spike = ${rgb(C.spike)}, Blink = ${rgb(N.blink)}, Tyre = ${rgb(C.tire)},
	} },\n`;
}
const tpl = fs.readFileSync(path.join(__dirname, "studio_mine_layer.template.luau"), "utf8");
fs.writeFileSync(path.join(__dirname, "studio_mine_layer.luau"), tpl.replace("--@@CARS@@\n", luaCars));
