# Nios Assembler

I took a course in microcomputers in school, which included writing some assembler code for
an Altera Nios processor. The assignments were quite simple, involving input/output, control flow
(branching and looping) and basic arithmetic operations. As bonus assignments, I created a small
game and a 3D "engine".

Nios is a RISC architecture FPGA. The version I used had a 32 bit processor with a clock
frequency of 33 MHz. The instruction set is quite limited. As can be seen in the 3D engine,
even multiplication and division had to be implemented from scratch (using addition, subtraction
and bit shifting).

Unfortunately, I don't have any screenshots of these programs.

## Tunnel Terror

A simple game which draws a winding tunnel on the screen. The tunnel becomes narrower and scrolls
up at an ever-increasing speed. The player controls a marker at the botoom of the screen, and must
steer left or right to remain inside the tunnel. Touching the tunnel walls ends the game.

## Nios 3D Engine

Features:

- 3D objects defined by vertices, polygons (triangles), and per-polygon color
- Predefined models: cube and icosahedron
- Rotation by matrix multiplication
- Back-face culling (detection and removal of polygons facing away from the camera)
- Lambertian shading
- Scanline triangle filling
- Coloring and shading using ANSI colors and graphic characters
- 16.16 bit fixed point signed math
- Multiplication / division implemented with loop unrolling for maximum performance
