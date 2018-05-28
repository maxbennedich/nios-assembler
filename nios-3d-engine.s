;NIOS 3D engine
;by Max Bennedich
;February 2004

;IMPORTANT NOTE: Terminal font should be set to 'Terminal' !!!
;Mode should be ANSI, and resolution 80x25.

  .include "nios.s"

;-----------------------------------------------------------------------------
;DATA
  .data

;constants
XSCALE = 200*65536       ;object scaling
YSCALE = 70*65536
ZDIST = 5*65536          ;distance camera <-> object

XMID = 40                ;center of screen
YMID = 13

UART = 0x400             ;uart adress

MODEL = 1                ;0 = cube  1 = icosahedron

;rotation matrix
rotmatrix:
  .word  65525,   636,  -996
  .word   -655, 65520, -1301
  .word    983,  1310, 65516

;object vertices, interleaved with projected vertices
.macro vertex p1, p2, p3
  .word \p1, \p2, \p3
  .word 0, 0
.endm

vert:
.if MODEL == 0
  vertex -32768, -32768, -32768
VERTSIZE = . - vert
  vertex -32768, -32768,  32768
  vertex -32768,  32768, -32768
  vertex -32768,  32768,  32768
  vertex  32768, -32768, -32768
  vertex  32768, -32768,  32768
  vertex  32768,  32768, -32768
  vertex  32768,  32768,  32768
.else
V1 = 27984
V2 = 45351
  vertex -V2,   0,  V1
VERTSIZE = . - vert
  vertex   0,  V1, -V2
  vertex   0,  V1,  V2
  vertex  V2,   0, -V1
  vertex -V1, -V2,   0
  vertex -V1,  V2,   0
  vertex   0, -V1,  V2
  vertex  V1,  V2,   0
  vertex   0, -V1, -V2
  vertex  V2,   0,  V1
  vertex  V1, -V2,   0
  vertex -V2,   0, -V1
.endif
NVERT = (. - vert)/VERTSIZE

;polygon (triangle) indices and color
.macro polygon v1, v2, v3, col
  .word \v1*VERTSIZE, \v2*VERTSIZE, \v3*VERTSIZE, \col
.endm

poly:
.if MODEL == 0
  polygon  1, 0, 2, '4'
POLYSIZE = . - poly
  polygon  2, 3, 1, '4'
  polygon  2, 6, 7, '2'
  polygon  7, 3, 2, '2'
  polygon  2, 0, 4, '1'
  polygon  4, 6, 2, '1'
  polygon  4, 0, 1, '3'
  polygon  1, 5, 4, '3'
  polygon  1, 3, 7, '7'
  polygon  7, 5, 1, '7'
  polygon  4, 5, 7, '5'
  polygon  7, 6, 4, '5'
.else
  polygon  9, 6, 2, '4'
POLYSIZE = . - poly
  polygon  1, 5,11, '2'
  polygon 11, 8, 1, '3'
  polygon  0, 4,11, '5'
  polygon  3, 7, 1, '1'
  polygon  3, 1, 8, '6'
  polygon  9, 7, 3, '1'
  polygon  0, 2, 6, '7'
  polygon  4, 6,10, '2'
  polygon  1, 7, 5, '6'
  polygon  7, 2, 5, '5'
  polygon  8,10, 3, '3'
  polygon  4, 8,11, '4'
  polygon  9, 2, 7, '7'
  polygon 10, 6, 9, '1'
  polygon  0,11, 5, '2'
  polygon  0, 5, 2, '4'
  polygon  8, 4,10, '5'
  polygon  3,10, 9, '3'
  polygon  6, 4, 0, '6'
;white-blue: 74444774747474444474
.endif
NPOLY = (. - poly)/POLYSIZE

;white-blue cube
;poly:
;  polygon  1, 0, 2, '7'
;  polygon  2, 3, 1, '4'
;  polygon  6, 7, 3, '7'
;  polygon  3, 2, 6, '4'
;  polygon  2, 0, 4, '7'
;  polygon  4, 6, 2, '4'
;  polygon  4, 0, 1, '7'
;  polygon  1, 5, 4, '4'
;  polygon  3, 7, 5, '7'
;  polygon  5, 1, 3, '4'
;  polygon  5, 7, 6, '7'
;  polygon  6, 4, 5, '4'

;terminal buffer
termbufptr:  .word  .
termbuf:

;NO DATA AFTER TERMBUF - it will be overwritten

;-----------------------------------------------------------------------------
;CODE
  .text
  .global main

;MAIN
;program start
main:

  bsr    init            ;initialize screen, etc
  nop

mainloop:
  bsr    rotateandproject ;rotate object and project 3d vertices to 2d
  nop

  bsr    render          ;draw visible polys to terminal
  nop

  bsr    flushbuffer     ;flush terminal buffer to screen
  nop

  MOVIP  %o0, 50
  bsr    nr_delay        ;pause for a while
  nop

  br     mainloop        ;repeat
  nop


;-----------------------------------------------------------------------------
;INIT
;initialization code

init:
  save   %sp, 0

;set background color to black
  MOVIA  %o1, termbufptr
  ld     %o1, [%o1]

  bsr    writechar
  movi   %o0, 0x1b       ;escape
  MOVIP  %o0, '['
  bsr    writechar
  nop
  MOVIP  %o0, '4'
  bsr    writechar
  nop
  MOVIP  %o0, '0'
  bsr    writechar
  nop
  MOVIP  %o0, 'm'
  bsr    writechar       ;set attribute!
  nop

  MOVIA  %o0, termbufptr
  bsr    flushbuffer
  st     [%o0], %o1

  RESTRET


;-----------------------------------------------------------------------------
;ROTATEANDPROJECT
;rotate object by applying rotation matrix to all vertices
;projects all 3d vertices to 2d
;cost: 2 divisions and 11 multiplications per vertex

rotateandproject:
  MOVIA  %L1, rotmatrix  ;L1 = pointer to rotation matrix

  ldp    %o0, [%L1,0]    ;the nine elements of the rotation matrix...
  ldp    %o1, [%L1,1]
  ldp    %o2, [%L1,2]
  ldp    %o3, [%L1,3]
  ldp    %o4, [%L1,4]

  mov    %o5, %L1
  save   %sp, 0          ;more registers needed...

  mov    %L1, %i5
  ldp    %L2, [%L1,5]
  ldp    %L3, [%L1,6]
  ldp    %L4, [%L1,7]
  ldp    %L5, [%L1,8]

  MOVIA  %L0, vert       ;L0 = index to vertices
  MOVI16 %o4, NVERT      ;o4 = counter
;  MOVIP  %L6, XSCALE     ;L6 = x scale
;  MOVIP %L7, YSCALE      ;L7 = y scale
  MOVIP  %L6, XMID*65536 + 32768 ;L6 = center + round x
  MOVIP  %L7, YMID*65536 + 32768 ;L7 = center + round y
  MOVIP  %L1, ZDIST      ;L1 = object distance from camera

;loop for each vertex
vertexloop:
;rotate
  ldp    %o1, [%L0,0]    ;x
  bsr    mulfp
  mov    %o0, %i0
  mov    %o2, %o0        ;x2 = R[1,1]*x

  bsr    mulfp
  mov    %o0, %i3
  mov    %o3, %o0        ;y2 = R[2,1]*x

  bsr    mulfp
  mov    %o0, %L3
  mov    %o5, %o0        ;z2 = R[3,1]*x

  ldp    %o1, [%L0,1]    ;y
  bsr    mulfp
  mov    %o0, %i1
  add    %o2, %o0        ;x2 = R[1,1]*x + R[1,2]*y

  bsr    mulfp
  mov    %o0, %i4
  add    %o3, %o0        ;y2 = R[2,1]*x + R[2,2]*y

  bsr    mulfp
  mov    %o0, %L4
  add    %o5, %o0        ;z2 = R[3,1]*x + R[3,2]*y

  ldp    %o1, [%L0,2]    ;z
  bsr    mulfp
  mov    %o0, %i2
  add    %o2, %o0        ;x2 = R[1,1]*x + R[1,2]*y + R[1,3]*z
  stp    [%L0,0], %o2    ;store new x

  bsr    mulfp
  mov    %o0, %L2
  add    %o3, %o0        ;y2 = R[2,1]*x + R[2,2]*y + R[2,3]*z
  stp    [%L0,1], %o3    ;store new y

  bsr    mulfp
  mov    %o0, %L5
  add    %o5, %o0        ;z2 = R[3,1]*x + R[3,2]*y + R[3,3]*z
  stp    [%L0,2], %o5    ;store new z

;project vertex to 2d
  mov    %o0, %o2        ;x
  lsli   %o0, 7          ;o0 = 128*x
;  bsr    mulfp           ;o0 = xscale*x
;  mov    %o1, %L6
  add    %o5, %L1        ;z+zdist
  bsr    divfp           ;o0 = xscale*x/(z+zdist)
  mov    %o1, %o5
  add    %o0, %L6
  asri   %o0, 16
  lsli   %o0, 16         ;o0 = rounded integer
  stp    [%L0,3], %o0    ;store projected x

  mov    %o0, %o3        ;y
  lsli   %o0, 6          ;o0 = 64*y
;  bsr    mulfp           ;o0 = yscale*y
;  mov    %o1, %L7
  bsr    divfp           ;o0 = yscale*y/(z+zdist)
  mov    %o1, %o5
  add    %o0, %L7
  asri   %o0, 16
  lsli   %o0, 16         ;o0 = rounded integer
  stp    [%L0,4], %o0    ;store projected y

  subi   %o4, 1          ;move indices forward and repeat
  skprz  %o4
  br     vertexloop
  addi   %L0, VERTSIZE

  RESTRET


;-----------------------------------------------------------------------------
;RENDER
;sees which polygons are visible, calculates shading and draws polys to screen
;cost: 2 multiplications per polygon, 2 more multiplications and
;      3 divisions per rendered polygon, plus the drawing itself

render:
  save   %sp, 0

;first clear screen
  MOVIA  %o1, termbufptr
  ld     %o1, [%o1]
  bsr    writechar
  movi   %o0, 0x1b       ;escape
  MOVIP  %o0, '['
  bsr    writechar
  nop
  MOVIP  %o0, '2'
  bsr    writechar
  nop
  MOVIP  %o0, 'J'
  bsr    writechar       ;clear screen!
  nop
  MOVIA  %o0, termbufptr
  st     [%o0], %o1

  MOVIA  %L6, vert       ;L6 = index to vertices
  MOVIA  %L0, poly       ;L0 = index to polys
  MOVI16 %L7, NPOLY      ;L7 = counter

;loop for each polygon
renderpolyloop:
  ldp    %L1, [%L0,0]    ;poly vertex #1
  add    %L1, %L6
  ldp    %L2, [%L0,1]    ;poly vertex #2
  add    %L2, %L6
  ldp    %L3, [%L0,2]    ;poly vertex #3
  add    %L3, %L6

;calculate z component of normal to see if *projected* triangle is facing viewer
  ldp    %L4, [%L1,3]    ;proj1.x
  ldp    %L5, [%L1,4]    ;proj1.y
  ldp    %o0, [%L2,4]    ;proj2.y
  ldp    %o1, [%L3,3]    ;proj3.x
  sub    %o0, %L5
  bsr    mulfp           ;o0 = (proj2.y-proj1.y)*(proj3.x-proj1.x)
  sub    %o1, %L4
  mov    %o5, %o0        ;store away o0

  ldp    %o0, [%L2,3]    ;proj2.x
  ldp    %o1, [%L3,4]    ;proj3.y
  sub    %o0, %L4
  bsr    mulfp           ;o0 = (proj2.x-proj1.x)*(proj3.y-proj1.y)
  sub    %o1, %L5

  sub    %o0, %o5
  skps   cc_gt
  br     hiddensurface   ;surface is hidden, don't draw it
  subi   %L7, 1          ;use branch slot to decrease loop counter

;calculate shading based on z component of normal
  ldp    %L4, [%L1,0]    ;vert1.x
  ldp    %L5, [%L1,1]    ;vert1.y
  ldp    %o0, [%L3,1]    ;vert3.y
  ldp    %o1, [%L2,0]    ;vert2.x
  sub    %o0, %L5
  bsr    mulfp           ;o0 = (vert3.y-vert1.y)*(vert2.x-vert1.x)
  sub    %o1, %L4
  mov    %o4, %o0        ;store away o0

  ldp    %o0, [%L3,0]    ;vert3.x
  ldp    %o1, [%L2,1]    ;vert2.y
  sub    %o0, %L4
  bsr    mulfp           ;o0 = (vert3.x-vert1.x)*(vert2.y-vert1.y)
  sub    %o1, %L5

  sub    %o4, %o0
.if MODEL == 1
  mov    %o0, %o4        ;if icosahedron, faces are smaller, so amplify shading
  add    %o4, %o4        ;ideally we should check the length of the normal or something
  add    %o4, %o0        ; but this would require to take the square root...
  asri   %o4, 1          ;o4 = o4*1.5
.endif
  skp0   %o4, 16         ;prevent overflow due to rounding errors
  MOVI16 %o4, 65535      ;clamp at max value
  asri   %o4, 13
  subi   %o4, 2
  skps   cc_ge
  xor    %o4, %o4        ;clamp at min value

;set up parameters and draw poly
  mov    %o0, %L1
  mov    %o1, %L2
  mov    %o2, %L3
  ldp    %o3, [%L0,3]    ;color
  bsr    fillpoly        ;draw polygon!
  nop

hiddensurface:
  skprz  %L7             ;repeat for all polys...
  br     renderpolyloop
  addi   %L0, POLYSIZE

  RESTRET


;-----------------------------------------------------------------------------
;FILLPOLY
;draws a filled triangle
;cost: 3 divisions, plus the drawing of the triangle
;assumes:
; o0, o1, o2 = poly vertices
; o3 = color (ansi style, '0'-'7')
; o4 = shade (in the range 0-5)

fillpoly:
  save   %sp, 0

;first send color and shading info to uart
  MOVIA  %o1, termbufptr
  ld     %o1, [%o1]
  bsr    writechar
  movi   %o0, 0x1b       ;escape
  MOVIP  %o0, '['
  bsr    writechar
  nop

  MOVIP  %o0, '1'        ;bright mode
  skp0   %i4, 2
  br     shadeok
  mov    %o2, %i3
  CMPIP  %o2, '7'        ;white color?
  skps   cc_z
  br     shadeok         ;no
  subi   %o0, 1          ;normal mode
  addi   %o0, 1          ;white color? then bright mode after all
  subi   %o2, 7          ;and change color to dark gray

shadeok:
  bsr    writechar
  nop

  MOVIP  %o0, ';'
  bsr    writechar
  nop
  MOVIP  %o0, '3'
  bsr    writechar
  nop
  bsr    writechar
  mov    %o0, %o2
  MOVIP  %o0, 'm'
  bsr    writechar       ;set attribute!
  nop
  MOVIA  %o0, termbufptr
  st     [%o0], %o1

;sort projected vertices for increasing y coordinate
  mov    %L1, %i0
  mov    %L2, %i1
  mov    %L3, %i2

  ldp    %L4, [%L1,3]    ;proj1.x
  ldp    %L5, [%L1,4]    ;proj1.y

  ldp    %L6, [%L2,4]    ;proj2.y
  ldp    %L1, [%L2,3]    ;proj2.x

  cmp    %L5, %L6
  skps   cc_gt
  br     sort1
  ldp    %L7, [%L3,4]    ;proj3.y
  xor    %l5, %l6        ;exchange vert 1 & 2
  xor    %l6, %l5
  xor    %l5, %l6
  xor    %l4, %l1
  xor    %l1, %l4
  xor    %l4, %l1
sort1:

  cmp    %L6, %L7
  skps   cc_gt
  br     sort2
  ldp    %o5, [%L3,3]    ;proj3.x
  xor    %l6, %l7        ;exchange vert 2 & 3
  xor    %l7, %l6
  xor    %l6, %l7
  xor    %l1, %o5
  xor    %o5, %l1
  xor    %l1, %o5
sort2:

  cmp    %L5, %L6
  skps   cc_gt
  br     sort3
  mov    %o0, %o5
  xor    %l5, %l6        ;exchange vert 1 & 2 again
  xor    %l6, %l5
  xor    %l5, %l6
  xor    %l4, %l1
  xor    %l1, %l4
  xor    %l4, %l1
sort3:

;calculate x increments
  sub    %o0, %L4
  mov    %o1, %L7
  bsr    divfp
  sub    %o1, %L5
  mov    %o2, %o0        ;o2 = deltax(p3-p1)

  mov    %o0, %o5
  sub    %o0, %L1
  mov    %o1, %L7
  bsr    divfp
  sub    %o1, %L6
  mov    %L2, %o0        ;L2 = deltax(p3-p2)

  mov    %o0, %L1
  sub    %o0, %L4
  mov    %o1, %L6
  bsr    divfp           ;o0 = deltax(p2-p1)
  sub    %o1, %L5

;set up start values
  mov    %L3, %o2        ;L3 = deltax2
  asri   %o2, 1
  add    %o2, %L4
  ADDIP  %o2, 1<<15      ;o2 = start x

  mov    %o5, %L5
  asri   %o5, 16         ;o5 = start y

  mov    %L5, %o0        ;L5 = deltax1
  asri   %o0, 1
  add    %o0, %L4
  ADDIP  %o0, 1<<15      ;o0 = end x

  asri   %L6, 16         ;L6 = mid y
  asri   %L7, 16         ;L7 = end y

;convert shade to corresponding screen character
  mov    %o4, %i4        ;shade
  skp0   %o4, 2
  subi   %o4, 2          ;4,5 -> 2,3
  cmpi   %o4, 3
  skps   cc_nz
  ADDIP  %o4, 219-179
  ADDIP  %o4, 176        ;0,1,2,3 -> 176,177,178,219

;convert hex line number to decimal ascii, simulate division by using
;the fact that 13/128 = 0.101... (works for all numbers < 69)
  mov    %o3, %o5        ;o3 = y
  add    %o3, %o3        ;o3 = 2*y
  add    %o3, %o5        ;o3 = 3*y
  lsli   %o3, 2          ;o3 = 12*y
  add    %o3, %o5        ;o3 = 13*y
  asri   %o3, 7          ;o3 = 13*y / 128 = x/9.84  ->  second digit
  mov    %o1, %o3
  lsli   %o1, 3          ;o1 = 8*o3
  add    %o1, %o3
  add    %o1, %o3        ;o1 = 10*o3
  sub    %o1, %o5
  neg    %o1             ;o1 = remainder after division  ->  first digit

  ADDIP  %o1, '0'        ;make digits ascii
  ADDIP  %o3, '0'
  MOVIP  %L4, '9'        ;decimal digit limit

;loop through all scan lines
traceline:
  cmp    %o5, %L7        ;done?
  skps   cc_ne
  br     tracedone       ;yes
  nop

  cmp    %o5, %L6        ;reached midpoint?
  skps   cc_z
  br     nomid           ;no
  nop

  mov    %o0, %L2
  asri   %o0, 1
  add    %o0, %L1
  ADDIP  %o0, 1<<15      ;o0 = new end x
  mov    %L5, %L2        ;deltax1 = deltax3

nomid:
  bsr    drawline        ;draw line
  nop

  cmp    %o1, %L4        ;compare first line digit to '9'
  skps   cc_ge
  br     digitok
  addi   %o1, 1          ;increase first line digit
  subi   %o1, 10         ;reset to 0
  addi   %o3, 1          ;increase second line digit
digitok:

  add    %o2, %L3        ;advance edge points
  add    %o0, %L5
  br     traceline
  addi   %o5, 1

tracedone:
  RESTRET


;-----------------------------------------------------------------------------
;DRAWLINE
;draws a single horizontal line
;cost: 8+abs(o0-o2) uart writes
;assumes:
; o2,o0 = x1,x2 (unsorted)
; o4 = shade
; o1 = first line digit (ascii)
; o3 = second line digit

drawline:
  save   %sp, 0

;put lowest x in L0 and number of pixels in o2
  mov    %o2, %i2
  mov    %o0, %i0
  asri   %o2, 16
  asri   %o0, 16
  mov    %L0, %o2
  sub    %o2, %o0
  skps   cc_nz
  br     drawdone        ;return if line is of zero length
  abs    %o2
  skps   cc_mi
  mov    %L0, %o0

;create and send escape code to position cursor
  MOVIA  %o1, termbufptr
  ld     %o1, [%o1]
  bsr    writechar
  movi   %o0, 0x1b       ;escape
  MOVIP  %o0, '['
  bsr    writechar
  nop

  CMPIP  %i3, '0'
  skps   cc_nz
  br     linesecondzero
  nop
  bsr    writechar       ;write second digit of line
  mov    %o0, %i3

linesecondzero:
  bsr    writechar       ;write first digit of line
  mov    %o0, %i1
  MOVIP  %o0, ';'
  bsr    writechar
  nop

;convert hex column number to decimal, simulate division by using
;the fact that 205/2048 = 0.10009... (works for all numbers < 1029)
  mov    %L1, %L0        ;L1 = x
  add    %L1, %L1        ;L1 = 2*x
  add    %L1, %L0        ;L1 = 3*x
  lsli   %L1, 2          ;L1 = 12*x
  mov    %L2, %L0
  add    %L0, %L1        ;L0 = 13*x
  lsli   %L1, 4          ;L1 = 192*x
  add    %L0, %L1        ;L0 = 205*x
  asri   %L0, 11         ;L0 = 205*x / 2048 = x/9.99  ->  second digit
  skprnz %L0
  br     colsecondzero   ;don't write if zero
  mov    %L1, %L0

  mov    %o0, %L0
  ADDIP  %o0, '0'
  bsr    writechar       ;write second digit of column

colsecondzero:
  lsli   %L1, 3          ;L1 = 8*L0
  add    %L1, %L0
  add    %L1, %L0        ;L1 = 10*L0
  sub    %L2, %L1        ;L2 = remainder after division  ->  first digit

  mov    %o0, %L2
  ADDIP  %o0, '0'
  bsr    writechar       ;write first digit of column
  nop
  MOVIP  %o0, 'H'
  bsr    writechar       ;move cursor!
  nop

;now send line itself, o2 pixels of shade i4
  mov    %o0, %i4
drawpixel:
  bsr    writechar
  subi   %o2, 1
  skprz  %o2
  br     drawpixel
  nop

  MOVIA  %o0, termbufptr
  st     [%o0], %o1

drawdone:
  RESTRET


;-----------------------------------------------------------------------------
;WRITECHAR
;writes character %o0 into terminal buffer at position %o1

writechar:
  fill8  %r0, %o0
  st8d   [%o1], %r0      ;write character
  jmp    %o7
  addi   %o1, 1


;-----------------------------------------------------------------------------
;FLUSHBUFFER
;flush terminal buffer to UART

flushbuffer:
  save   %sp, 0

;first move cursor out of the way
  MOVIA  %o1, termbufptr
  mov    %o5, %o1
  ld     %o1, [%o1]
  bsr    writechar
  movi   %o0, 0x1b       ;escape
  MOVIP  %o0, '['
  bsr    writechar
  nop
  MOVIP  %o0, '0'
  bsr    writechar
  nop
  MOVIP  %o0, ';'
  bsr    writechar
  nop
  MOVIP  %o0, '0'
  bsr    writechar
  nop
  MOVIP  %o0, 'H'
  bsr    writechar       ;move cursor!
  nop

;now flush
  MOVIA  %o2, termbuf    ;points to current character
  mov    %o3, %o1        ;end of buffer
  st     [%o5], %o2      ;reset buffer pointer
  MOVIP  %o1, UART
  movi   %o5, 4          ;counter AND 3

loopbufferword:
  ld     %o4, [%o2]
loopbufferbyte:
  cmp    %o2, %o3
  skps   cc_nz
  br     bufferempty

  mov    %o0, %o4
  ext8d  %o0, %o2        ;extract character

waitready:
  pfx    np_uartstatus   ;status register for uart
  ld     %g1, [%o1]
  skp1   %g1, np_uartstatus_trdy_bit ;check the ready bit
  br     waitready       ;loop until empty
  nop

  pfx    np_uarttxdata
  st     [%o1], %o0      ;put char into UART

  subi   %o5, 1
  skps   cc_z
  br     loopbufferbyte
  addi   %o2, 1
  br     loopbufferword  ;every 4th byte, reload a word from the buffer
  movi   %o5, 4

bufferempty:
  RESTRET


;-----------------------------------------------------------------------------
;MULFP
;16.16 fixed point signed multiplication, o0 <- o0 * o1
;unrolled for maximum speed

;integer step
.macro MISTEP bit
  skp0   %o3, \bit
  add    %i0, %o1
  lsli   %o1, 1
.endm

;floating step
.macro MFSTEP bit
  lsri   %o4, 1
  skp0   %o3, \bit
  add    %i0, %o4
.endm

mulfp:
  save   %sp, 0

;sign check
  mov    %o3, %i0
  mov    %o4, %i1
  mov    %o0, %i0
  xor    %o0, %i1        ;bit 31 of o0 is sign of result
  abs    %o3             ;o3 = abs(i0)
  abs    %o4             ;o4 = abs(i1)

;integer part
  xor    %i0, %i0
  mov    %o1, %o4

  MISTEP 16
  MISTEP 17
  MISTEP 18
  MISTEP 19
  MISTEP 20
  MISTEP 21
  MISTEP 22
  MISTEP 23
  MISTEP 24
  MISTEP 25
  MISTEP 26
  MISTEP 27
  MISTEP 28
  MISTEP 29
  MISTEP 30
  skp0   %o3, 31         ;do last step manually...
  add    %i0, %o1        ; saves one instruction

;floating part
  MFSTEP 15
  MFSTEP 14
  MFSTEP 13
  MFSTEP 12
  MFSTEP 11
  MFSTEP 10
  MFSTEP 9
  MFSTEP 8
  MFSTEP 7
  MFSTEP 6
  MFSTEP 5
  MFSTEP 4
  MFSTEP 3
  MFSTEP 2
  MFSTEP 1
  MFSTEP 0

;fix sign
  skp0   %o0, 31
  neg    %i0

  RESTRET


;-----------------------------------------------------------------------------
;DIVFP
;16.16 fixed point signed division, o0 <- o0 / o1
;unrolled for maximum speed (nevertheless, it is very slow)

;integer step
.macro DISTEP bit
  mov    %o2, %o3        ;o2 = temp shifted D
  lsri   %o2, \bit
  cmp    %o4, %o2        ;see if 2^x * Q < D
  skps   cc_le
  br     noadd\@
  lsli   %i0, 1
  mov    %o5, %o4        ;o5 = temp shifted Q
  lsli   %o5, \bit
  sub    %o3, %o5        ;subtract 2^x * Q from D
  addi   %i0, 1          ;set bit x in result
noadd\@:
.endm

;floating step, shorter than integer since no overflow control is needed
.macro DFSTEP
  lsri   %o4, 1
  cmp    %o4, %o3
  skps   cc_le
  br     noadd\@
  lsli   %i0, 1
  sub    %o3, %o4
  addi   %i0, 1
noadd\@:
.endm

divfp:
  save   %sp, 0

;sign check
  mov    %o3, %i0
  mov    %o4, %i1
  mov    %o0, %i0
  xor    %o0, %i1        ;bit 31 of o0 is sign of result
  abs    %o3             ;o3 = abs(D)
  abs    %o4             ;o4 = abs(Q)

  xor    %i0, %i0

  DISTEP 15
  DISTEP 14
  DISTEP 13
  DISTEP 12
  DISTEP 11
  DISTEP 10
  DISTEP 9
  DISTEP 8
  DISTEP 7
  DISTEP 6
  DISTEP 5
  DISTEP 4
  DISTEP 3
  DISTEP 2
  DISTEP 1
  DISTEP 0

  .rept 16
  DFSTEP
  .endr

;fix sign
  skp0   %o0, 31
  neg    %i0

  RESTRET

  .end main
