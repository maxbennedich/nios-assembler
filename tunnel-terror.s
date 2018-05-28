;Tunnel Terror by Max Bennedich 2004-02-19

  .include "nios.s"

.equ MAXWID , 40
.equ MAXCNT , 50

  .data
  .text
  .global main

main:
  MOVI16 %o1, 8          ;o1 = x start
  MOVI16 %o2, 24         ;o2 = width
  MOVI16 %o3, MAXWID/2   ;o3 = player position
  movi   %o4, 0          ;o4 = score
  MOVI16 %o5, MAXCNT     ;o5 = counter
  MOVI16 %L1, 60         ;L1 = speed

mainloop:
  bsr    nr_pio_showhex  ;show difficulty on NIOS hex display
  mov    %o0, %o2

  bsr    drawline        ;draw a line
  nop

  bsr    putscore        ;draw score
  mov    %o0, %o4

  bsr    tick            ;update score
  nop
  mov    %o4, %o0

  bsr    updatetunnel    ;move tunnel
  nop

  bsr    updateplayer    ;read keyboard and update player
  nop

  mov    %o0, %L1
  bsr    nr_delay        ;pause for a while
  nop

  cmpi   %o2, 0
  skps   cc_le
  br     mainloop        ;repeat
  nop

gameover:
  br     gameover
  nop


;UPDATETUNNEL
; moves start of tunnel in %o1
updatetunnel:

;see if tunnel gets narrower
  subi   %o5, 1
  skps   cc_le
  br     nochange
  MOVI16 %o5, MAXCNT     ;reset counter
  subi   %o2, 1          ;decrease tunnel width
  subi   %L1, 2          ;speed up simulation
nochange:

;create "random" value in L0
  add    %L0, %o4
  XORIP  %L0, 41397
  addi   %L0, 23
  xor    %L0, %o4
  lsri   %L0, 1
  addi   %o1, 1
  skp0   %L0, 0
  subi   %o1, 2

;see if it's outside limits
  skps   cc_gt
  movi   %o1, 1

  MOVI16 %g0, MAXWID
  sub    %g0, %o2
  subi   %g0, 1
  cmp    %o1, %g0
  skps   cc_lt
  mov    %o1, %g0

  jmp    %o7
  nop


;DRAWLINE
; draws a line from %o1 to %o1+%o2 with player at %o3

;draw macro
; draws %o2 chars of %o0 with uart %o1
.macro mdraw
  subi   %o2, 1
draw\@:
  bsr    nr_uart_txchar
  subi   %o2, 1
  skp1   %o2, 31
  br     draw\@
  nop
.endm

drawline:
  save   %sp, 0
  movia  %o1, 0x400

;draw left wall
  mov    %o2, %i1
  MOVI16 %o0, 'X'
  mdraw
  nop

;draw space left of player
  mov    %o2, %i3
  sub    %o2, %i1
  subi   %o2, 1
  skps   cc_gt
  br     wall1
  nop
  MOVI16 %o0, '-'
  mdraw
  nop

;draw player
wall1:
  MOVI16 %o0, '.'
  bsr    nr_uart_txchar
  nop

;draw space right of player
  mov    %o2, %i1
  add    %o2, %i2
  sub    %o2, %i3
  skps   cc_gt
  br     wall2
  nop
  MOVI16 %o0, '-'
  mdraw
  nop

wall2:
  MOVI16 %o2, MAXWID
  sub    %o2, %i1
  sub    %o2, %i2
  MOVI16 %o0, 'X'
  mdraw
  nop

  RESTRET


;UPDATEPLAYER
; read keyboard, move player position in %o3 and test for death
updateplayer:
  save   %sp, 0
  MOVIA  %o0, 0x400
  bsr    nr_uart_rxchar  ;read terminal input
  nop
  CMPIP  %o0, 'D'
  skps   cc_ne
  subi   %i3, 1          ;move player left
  CMPIP  %o0, 'C'
  skps   cc_ne
  addi   %i3, 1          ;move player right

;see if player hits wall
  cmp    %i3, %i1
  skps   cc_gt
  movi   %i2, 0          ;-> game over
  mov    %o0, %i1
  add    %o0, %i2
  cmp    %i3, %o0
  skps   cc_le
  movi   %i2, 0          ;-> game over
  RESTRET


;PUTSCORE
; prints 4-digit decimal value in %o0
putscore:
  save   %sp, 0
  movia  %o1, 0x400

  MOVI16 %o0, 32
  bsr    nr_uart_txchar

  movi   %o2, 12

prntdig:
  mov    %o0, %i0
  lsr    %o0, %o2
  ANDIP  %o0, 0x0f
  ADDIP  %o0, '0'
  bsr    nr_uart_txchar
  nop
  subi   %o2, 4
  skps   cc_mi
  bsr    prntdig
  nop

  bsr    nr_uart_txchar
  movi   %o0, 10

  bsr    nr_uart_txchar
  movi   %o0, 13

  RESTRET


;TICK
; increase 4-digit decimal value in %o0
tick:
  save   %sp, 0
  movi   %g2, 1          ;%g2 = amount to increase time with
  movi   %g3, 0x0f       ;%g3 = mask to extract individual digit
  movi   %g4, 6          ;%g4 = amount to increase time with at wrap-over
  movi   %g5, 0x0a       ;%g5 = wrap-over limit

dloop:
  add    %i0, %g2        ;advance time
  mov    %g1, %i0
  and    %g1, %g3        ;extract individual digit
  mov    %g2, %g4        ;increase time with %g4 next time
  lsli   %g3, 4          ;next digit
  lsli   %g4, 4          ;limit = increment << 4
  cmp    %g1, %g5        ;overflow?
  skps   cc_lt
  br     dloop           ;repeat if overflow
  lsli   %g5, 4          ;increment = limit << 4
  RESTRET

.end main
