# Claw Machine v1

Arcade claw-machine prop for a Roblox CAR VS CAR lobby. Geometry only; no gameplay or animation included.

- Blender source: `claw-machine-v1.blend`
- Roblox import: `claw-machine-v1.fbx` (unitless scale, about 7 × 7.5 × 12 studs; forward Z, up Y)
- Portable preview: `claw-machine-v1.glb`
- Render: `claw-machine-v1-preview.png`
- Origin: center of plinth at floor level; lowest geometry sits at z=0.
- Front faces negative Y in Blender.
- Colors: red enamel cabinet and rear wall, yellow frame and marquee, charcoal base, blue action button, silver gantry and claw.
- Structure: named meshes for cabinet, panes, gantry, cable, claw fingers, controls, service door, and chute. Empty pivots group the asset, carriage and claw rig, three finger hinges, joystick, and action button. Mesh object scales are applied.
- Complexity: 81 mesh objects; exported meshes contain 7,256 triangles with bevels applied.
- The playfield includes an open drop aperture and the lower cabinet has a Boolean-cut collection opening. The chute is static geometry, with no gameplay mechanism.

The claw is visibly open. Marquee, display, and payment label are blank for later branding.

FBX and GLB have been reimported and checked in Blender. Roblox Studio import has not been tested; glass transparency and collision will need to be configured in Studio. The pivot hierarchy provides modeling controls, not a Roblox animation rig.




