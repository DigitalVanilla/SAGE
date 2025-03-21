;--------------------------------------
; sage_3dfastmap.asm
;
; SAGE (Simple Amiga Game Engine) project
; Fast mapping functions
; 
; @author Fabrice Labrador <fabrice.labrador@gmail.com>
; @version 1.0 January 2022
;--------------------------------------

; Delta variables
DELTA_DXDYL         EQU 0*4
DELTA_DUDYL         EQU 1*4
DELTA_DVDYL         EQU 2*4
DELTA_DXDYR         EQU 3*4
DELTA_DUDYR         EQU 4*4
DELTA_DVDYR         EQU 5*4
DELTA_DU            EQU 6*4
DELTA_DV            EQU 7*4
DELTA_DZDYL         EQU 8*4
DELTA_DZDYR         EQU 9*4
DELTA_DZ            EQU 10*4

; Coordinate variables
CRD_XL              EQU 0*4
CRD_XR              EQU 1*4
CRD_UL              EQU 2*4
CRD_VL              EQU 3*4
CRD_UR              EQU 4*4
CRD_VR              EQU 5*4
CRD_LINE            EQU 6*4
CRD_LCLIP           EQU 7*4
CRD_RCLIP           EQU 8*4
CRD_TCOLOR          EQU 9*4
CRD_ZL              EQU 10*4
CRD_ZR              EQU 11*4

FIXP16_ROUND_UP     EQU $8000

  SECTION fastmap,code

;--------------------------------------
; Clear the z buffer
;
; @in a0.l z buffer address
; @in d0.w number of lines to clear
; @in d1.w number of bytes per line
;
; @out d0.l Operation success
;--------------------------------------
  xdef _SAGE_FastClearZBuffer

_SAGE_FastClearZBuffer:
  movem.l d1/d2/d6/a0,-(sp)
  move.l  #$FFFFFFFF,d2
  lsr.w   #3,d1
  subq.w  #1,d1
  subq.w  #1,d0
.NextLine:
  move.w  d1,d6
.NextBlock:
  move.l  d2,(a0)+
  move.l  d2,(a0)+
  dbf     d6,.NextBlock
  dbf     d0,.NextLine
  movem.l (sp)+,d1/d2/d6/a0
  move.l  #-1,d0
  rts

;--------------------------------------
; Map a 8bits texture
;
; @in d0.l number of lines to map
; @in a0.l texture address
; @in d1.l texture width
; @in a1.l bitmap address
; @in d2.l bitmap width
; @in a2.l deltas array
; @in a3.l coords array
;
; @out d0.l operation success
;--------------------------------------
  xdef _SAGE_FastMap8BitsTexture

_SAGE_FastMap8BitsTexture:
  movem.l d1-d7/a0-a6,-(sp)
  tst.l   d0                            ; no lines ?
  ble     .EndDraw

  subq.l  #1,d0
.MapNextLine:

; Calcul edge coords
;  xs = (s3dm_coords[CRD_XL] + FIXP16_ROUND_UP) >> FIXP16_SHIFT;
;  xe = (s3dm_coords[CRD_XR] + FIXP16_ROUND_UP) >> FIXP16_SHIFT;
  move.l  CRD_XL(a3),d3                 ; xs
  addi.l  #FIXP16_ROUND_UP,d3
  swap    d3
  ext.l   d3
  move.l  CRD_XR(a3),d4                 ; xe
  addi.l  #FIXP16_ROUND_UP,d4
  swap    d4
  ext.l   d4

; Check for left/right clipping
;  if (xs < s3dm_coords[CRD_RCLIP] && xe >= s3dm_coords[CRD_LCLIP]) {
  cmp.l   CRD_RCLIP(a3),d3
  bge    .Interpolate
  cmp.l   CRD_LCLIP(a3),d4
  blt    .Interpolate

; Calcul interpolation
;  du = s3dm_coords[CRD_UR] - s3dm_coords[CRD_UL];
;  dv = s3dm_coords[CRD_VR] - s3dm_coords[CRD_VL];
;  dz = s3dm_coords[CRD_ZR] - s3dm_coords[CRD_ZL];
;  dx = xe - xs;
;  if (dx > 0) {
;    du /= dx;
;    dv /= dx;
;    dz /= dx;
;  }
  move.l  CRD_UR(a3),d5
  sub.l   CRD_UL(a3),d5
  move.l  CRD_VR(a3),d6
  sub.l   CRD_VL(a3),d6
  move.l  d4,d7
  sub.l   d3,d7                         ; dx
  ble.s   .DxNegative
  divs.l  d7,d5                         ; du
  divs.l  d7,d6                         ; dv
.DxNegative:
  move.l  d5,DELTA_DU(a2)
  move.l  d6,DELTA_DV(a2)

; Calcul texture coords
;  ui = s3dm_coords[CRD_UL] + FIXP16_ROUND_UP;
;  vi = s3dm_coords[CRD_VL] + FIXP16_ROUND_UP;
  move.l  CRD_UL(a3),d5                 ; ui
  addi.l  #FIXP16_ROUND_UP,d5
  move.l  CRD_VL(a3),d6                 ; vi
  addi.l  #FIXP16_ROUND_UP,d6

; Calcul Z value
;  zi = s3dm_coords[CRD_ZL] + FIXP16_ROUND_UP;


; Horizontal clipping
;  if (xs < s3dm_coords[CRD_LCLIP]) {
;    dx = s3dm_coords[CRD_LCLIP] - xs;
;    ui += dx * du;
;    vi += dx * dv;
;    zi += dx * dz;
;    xs = s3dm_coords[CRD_LCLIP];
;    dx = xe - xs;
;  }
;  if (xe >= s3dm_coords[CRD_RCLIP]) {
;    dx = (s3dm_coords[CRD_RCLIP] - 1) - xs;
;  }
  cmp.l   CRD_LCLIP(a3),d3
  bge.s   .NoLeftClip
  move.l  CRD_LCLIP(a3),d7
  sub.l   d3,d7
  move.l  DELTA_DU(a2),d3
  muls.l  d7,d3
  add.l   d3,d5
  move.l  DELTA_DV(a2),d3
  muls.l  d7,d3
  add.l   d3,d6
  move.l  CRD_LCLIP(a3),d3
  move.l  d4,d7
  sub.l   d3,d7
.NoLeftClip:
  cmp.l   CRD_RCLIP(a3),d4
  blt.s   .NoRightClip
  move.l  CRD_RCLIP(a3),d7
  subq.l  #1,d7
  sub.l   d3,d7
.NoRightClip:

; Calcul start address
;  screen_pixel = s3dm_coords[CRD_LINE] + xs;
  movea.l a1,a4
  adda.l  CRD_LINE(a3),a4
  adda.l  d3,a4                         ; start address

; Draw the line
;  dx++;    // Real number of points to draw
;  while (dx--) {
; Write the texel
;    texture_pixel = (ui >> FIXP16_SHIFT) + ((vi >> FIXP16_SHIFT) * texture_width);
;    screen_buffer[screen_pixel++] = texture[texture_pixel];
; Interpolate u & v
;    ui += du;
;    vi += dv;
;  }
.NextTexel:
; Write the texel
  move.l  d6,d4
  swap    d4
  mulu.w  d1,d4                         ; (vi >> FIXP16_SHIFT) * texture_width
  move.l  d5,d3
  swap    d3
  ext.l   d3
  add.l   d3,d4                         ; + ui >> FIXP16_SHIFT
  move.b  0(a0,d4.l),(a4)+
; Interpolate u & v
  add.l   DELTA_DU(a2),d5
  add.l   DELTA_DV(a2),d6
  dbf     d7,.NextTexel

.Interpolate:
; Interpolate next points
;  s3dm_coords[CRD_XL] += s3dm_deltas[DELTA_DXDYL];
;  s3dm_coords[CRD_ZL] += s3dm_deltas[DELTA_DZDYL];
;  s3dm_coords[CRD_UL] += s3dm_deltas[DELTA_DUDYL];
;  s3dm_coords[CRD_VL] += s3dm_deltas[DELTA_DVDYL];
;  s3dm_coords[CRD_XR] += s3dm_deltas[DELTA_DXDYR];
;  s3dm_coords[CRD_ZR] += s3dm_deltas[DELTA_DZDYR];
;  s3dm_coords[CRD_UR] += s3dm_deltas[DELTA_DUDYR];
;  s3dm_coords[CRD_VR] += s3dm_deltas[DELTA_DVDYR];
  move.l  DELTA_DXDYL(a2),d3
  add.l   d3,CRD_XL(a3)
  move.l  DELTA_DUDYL(a2),d4
  add.l   d4,CRD_UL(a3)
  move.l  DELTA_DVDYL(a2),d5
  add.l   d5,CRD_VL(a3)
  move.l  DELTA_DXDYR(a2),d3
  add.l   d3,CRD_XR(a3)
  move.l  DELTA_DUDYR(a2),d4
  add.l   d4,CRD_UR(a3)
  move.l  DELTA_DVDYR(a2),d5
  add.l   d5,CRD_VR(a3)

; Next line address
;  s3dm_coords[CRD_LINE] += screen_width;
  add.l   d2,CRD_LINE(a3)

  dbf     d0,.MapNextLine

.EndDraw:
  movem.l (sp)+,d1-d7/a0-a6
  move.l  #-1,d0
  rts

;--------------------------------------
; Map a 16bits texture
;
; @in d0.l number of lines to map
; @in a0.l texture address
; @in d1.l texture width
; @in a1.l bitmap address
; @in d2.l bitmap width
; @in a2.l deltas array
; @in a3.l coords array
;
; @out d0.l operation success
;--------------------------------------
  xdef _SAGE_FastMap16BitsTexture

_SAGE_FastMap16BitsTexture:
  movem.l d1-d7/a0-a6,-(sp)
  tst.l   d0                            ; no lines ?
  ble     .EndDraw

  move.l  CRD_LINE(a3),d7
  lsl.l   #1,d7
  move.l  d7,CRD_LINE(a3)               ; 16bits

  subq.l  #1,d0
.MapNextLine:

; Calcul edge coords
  move.l  CRD_XL(a3),d3                 ; xs
  addi.l  #FIXP16_ROUND_UP,d3
  swap    d3
  ext.l   d3
  move.l  CRD_XR(a3),d4                 ; xe
  addi.l  #FIXP16_ROUND_UP,d4
  swap    d4
  ext.l   d4

; Check for left/right clipping
.PointsOnScreen:
  cmp.l   CRD_RCLIP(a3),d3
  bge    .Interpolate
  cmp.l   CRD_LCLIP(a3),d4
  blt    .Interpolate

; Calcul texture interpolation
  move.l  CRD_UR(a3),d5
  sub.l   CRD_UL(a3),d5
  move.l  CRD_VR(a3),d6
  sub.l   CRD_VL(a3),d6
  move.l  d4,d7
  sub.l   d3,d7                         ; dx
  ble.s   .DxNegative
  divs.l  d7,d5                         ; du
  divs.l  d7,d6                         ; dv
.DxNegative:
  move.l  d5,DELTA_DU(a2)
  move.l  d6,DELTA_DV(a2)

; Calcul texture coords
  move.l  CRD_UL(a3),d5                 ; ui
  addi.l  #FIXP16_ROUND_UP,d5
  move.l  CRD_VL(a3),d6                 ; vi
  addi.l  #FIXP16_ROUND_UP,d6

; Horizontal clipping
  cmp.l   CRD_LCLIP(a3),d3
  bge.s   .NoLeftClip
  move.l  CRD_LCLIP(a3),d7
  sub.l   d3,d7
  move.l  DELTA_DU(a2),d3
  muls.l  d7,d3
  add.l   d3,d5
  move.l  DELTA_DV(a2),d3
  muls.l  d7,d3
  add.l   d3,d6
  move.l  CRD_LCLIP(a3),d3
  move.l  d4,d7
  sub.l   d3,d7
.NoLeftClip:
  cmp.l   CRD_RCLIP(a3),d4
  blt.s   .NoRightClip
  move.l  CRD_RCLIP(a3),d7
  subq.l  #1,d7
  sub.l   d3,d7
.NoRightClip:

; Calcul start address
  movea.l a1,a4
  adda.l  CRD_LINE(a3),a4
  lsl.l   #1,d3                         ; 16bits
  adda.l  d3,a4                         ; start address

; Draw the line
.NextTexel:
; Write the texel
  move.l  d6,d4
  swap    d4
  ext.l   d4
  mulu.l  d1,d4                         ; (vi >> FIXP16_SHIFT) * texture_width
  move.l  d5,d3
  swap    d3
  ext.l   d3
  add.l   d3,d3                         ; 16bits
  add.l   d3,d4                         ; + ui >> FIXP16_SHIFT
  move.w  0(a0,d4.l),(a4)+
; Interpolate u & v
  add.l   DELTA_DU(a2),d5
  add.l   DELTA_DV(a2),d6
  dbf     d7,.NextTexel

; Interpolate next points
.Interpolate:
  move.l  DELTA_DXDYL(a2),d3
  add.l   d3,CRD_XL(a3)
  move.l  DELTA_DUDYL(a2),d4
  add.l   d4,CRD_UL(a3)
  move.l  DELTA_DVDYL(a2),d5
  add.l   d5,CRD_VL(a3)
  move.l  DELTA_DXDYR(a2),d3
  add.l   d3,CRD_XR(a3)
  move.l  DELTA_DUDYR(a2),d4
  add.l   d4,CRD_UR(a3)
  move.l  DELTA_DVDYR(a2),d5
  add.l   d5,CRD_VR(a3)

; Next line address
  add.l   d2,CRD_LINE(a3)

  dbf     d0,.MapNextLine

.EndDraw:
  movem.l (sp)+,d1-d7/a0-a6
  move.l  #-1,d0
  rts

;--------------------------------------
; Map a 8bits flat color
;
; @in d0.l number of lines to map
; @in d1.l color
; @in a1.l bitmap address
; @in d2.l bitmap width
; @in a2.l deltas array
; @in a3.l coords array
;
; @out d0.l operation success
;--------------------------------------
  xdef _SAGE_FastMap8BitsColor

_SAGE_FastMap8BitsColor:
  movem.l d1-d7/a0-a6,-(sp)
  tst.l   d0                            ; no lines ?
  ble     .EndDraw

  subq.l  #1,d0
.MapNextLine:

; Calcul edge coords
  move.l  CRD_XL(a3),d3                 ; xs
  addi.l  #FIXP16_ROUND_UP,d3
  swap    d3
  ext.l   d3
  move.l  CRD_XR(a3),d4                 ; xe
  addi.l  #FIXP16_ROUND_UP,d4
  swap    d4
  ext.l   d4

; Check for left/right clipping
.PointsOnScreen:
  cmp.l   CRD_RCLIP(a3),d3
  bge    .Interpolate
  cmp.l   CRD_LCLIP(a3),d4
  blt    .Interpolate

  move.l  d4,d7
  sub.l   d3,d7                         ; dx

; Horizontal clipping
  cmp.l   CRD_LCLIP(a3),d3
  bge.s   .NoLeftClip
  move.l  CRD_LCLIP(a3),d3
  move.l  d4,d7
  sub.l   d3,d7
.NoLeftClip:
  cmp.l   CRD_RCLIP(a3),d4
  blt.s   .NoRightClip
  move.l  CRD_RCLIP(a3),d7
  subq.l  #1,d7
  sub.l   d3,d7
.NoRightClip:

; Calcul start address
  movea.l a1,a4
  adda.l  CRD_LINE(a3),a4
  adda.l  d3,a4                         ; start address

  addq.l  #1,d7                         ; at least we should draw 1 pixel
  move.l  d7,d6                         ; save the value
  andi.l  #$7,d6                        ; look for a multiple of 8
  beq.s   .DrawFastTexel                ; draw only block of eight texels
  subq.l  #1,d6                         ; extra texels to draw
.DrawExtraTexel:
  move.w  d1,(a4)+
  dbf     d6,.DrawExtraTexel
.DrawFastTexel:
  andi.l  #$fffffff8,d7                 ; clear low bits
  beq.s   .Interpolate                  ; nothing more to draw
  lsr.l   #3,d7                         ; draw 8 texels each time
  subq.l  #1,d7                         ; texels to draw
; Draw the line
.NextTexel:
  move.l  d1,(a4)+
  move.l  d1,(a4)+
  dbf     d7,.NextTexel

; Interpolate next points
.Interpolate:
  move.l  DELTA_DXDYL(a2),d3
  add.l   d3,CRD_XL(a3)
  move.l  DELTA_DXDYR(a2),d3
  add.l   d3,CRD_XR(a3)

; Next line address
  add.l   d2,CRD_LINE(a3)

  dbf     d0,.MapNextLine

.EndDraw:
  movem.l (sp)+,d1-d7/a0-a6
  move.l  #-1,d0
  rts

;--------------------------------------
; Map a 16bits flat color
;
; @in d0.l number of lines to map
; @in d1.l color
; @in a1.l bitmap address
; @in d2.l bitmap width
; @in a2.l deltas array
; @in a3.l coords array
;
; @out d0.l operation success
;--------------------------------------
  xdef _SAGE_FastMap16BitsColor

_SAGE_FastMap16BitsColor:
  movem.l d1-d7/a0-a6,-(sp)
  tst.l   d0                            ; no lines ?
  ble     .EndDraw

  move.l  CRD_LINE(a3),d7
  lsl.l   #1,d7
  move.l  d7,CRD_LINE(a3)               ; 16bits

  subq.l  #1,d0
.MapNextLine:

; Calcul edge coords
  move.l  CRD_XL(a3),d3                 ; xs
  addi.l  #FIXP16_ROUND_UP,d3
  swap    d3
  ext.l   d3
  move.l  CRD_XR(a3),d4                 ; xe
  addi.l  #FIXP16_ROUND_UP,d4
  swap    d4
  ext.l   d4

; Check for left/right clipping
.PointsOnScreen:
  cmp.l   CRD_RCLIP(a3),d3
  bge    .Interpolate
  cmp.l   CRD_LCLIP(a3),d4
  blt    .Interpolate

  move.l  d4,d7
  sub.l   d3,d7                         ; dx

; Horizontal clipping
  cmp.l   CRD_LCLIP(a3),d3
  bge.s   .NoLeftClip
  move.l  CRD_LCLIP(a3),d3
  move.l  d4,d7
  sub.l   d3,d7
.NoLeftClip:
  cmp.l   CRD_RCLIP(a3),d4
  blt.s   .NoRightClip
  move.l  CRD_RCLIP(a3),d7
  subq.l  #1,d7
  sub.l   d3,d7
.NoRightClip:

; Calcul start address
  movea.l a1,a4
  adda.l  CRD_LINE(a3),a4
  lsl.l   #1,d3                         ; 16bits
  adda.l  d3,a4                         ; start address

  addq.l  #1,d7                         ; at least we should draw 1 pixel
  move.l  d7,d6                         ; save the value
  andi.l  #$3,d6                        ; look for a multiple of 4
  beq.s   .DrawFastTexel                ; draw only block of eight texels
  subq.l  #1,d6                         ; extra texels to draw
.DrawExtraTexel:
  move.w  d1,(a4)+
  dbf     d6,.DrawExtraTexel
.DrawFastTexel:
  andi.l  #$fffffffc,d7                 ; clear low bits
  beq.s   .Interpolate                  ; nothing more to draw
  lsr.l   #2,d7                         ; draw 4 texels each time
  subq.l  #1,d7                         ; texels to draw
; Draw the line
.NextTexel:
  move.l  d1,(a4)+
  move.l  d1,(a4)+
  dbf     d7,.NextTexel

; Interpolate next points
.Interpolate:
  move.l  DELTA_DXDYL(a2),d3
  add.l   d3,CRD_XL(a3)
  move.l  DELTA_DXDYR(a2),d3
  add.l   d3,CRD_XR(a3)

; Next line address
  add.l   d2,CRD_LINE(a3)

  dbf     d0,.MapNextLine

.EndDraw:
  movem.l (sp)+,d1-d7/a0-a6
  move.l  #-1,d0
  rts
  
;--------------------------------------
; Map a 8bits transparent texture
;
; @in d0.l number of lines to map
; @in a0.l texture address
; @in d1.l texture width
; @in a1.l bitmap address
; @in d2.l bitmap width
; @in a2.l deltas array
; @in a3.l coords array
;
; @out d0.l operation success
;--------------------------------------
  xdef _SAGE_FastMap8BitsTransparent

_SAGE_FastMap8BitsTransparent:
  movem.l d1-d7/a0-a6,-(sp)
  tst.l   d0                            ; no lines ?
  ble     .EndDraw

  subq.l  #1,d0
.MapNextLine:

; Calcul edge coords
  move.l  CRD_XL(a3),d3                 ; xs
  addi.l  #FIXP16_ROUND_UP,d3
  swap    d3
  ext.l   d3
  move.l  CRD_XR(a3),d4                 ; xe
  addi.l  #FIXP16_ROUND_UP,d4
  swap    d4
  ext.l   d4

; Check for left/right clipping
  cmp.l   CRD_RCLIP(a3),d3
  bge    .Interpolate
  cmp.l   CRD_LCLIP(a3),d4
  blt    .Interpolate

; Calcul texture interpolation
  move.l  CRD_UR(a3),d5
  sub.l   CRD_UL(a3),d5
  move.l  CRD_VR(a3),d6
  sub.l   CRD_VL(a3),d6
  move.l  d4,d7
  sub.l   d3,d7                         ; dx
  ble.s   .DxNegative
  divs.l  d7,d5                         ; du
  divs.l  d7,d6                         ; dv
.DxNegative:
  move.l  d5,DELTA_DU(a2)
  move.l  d6,DELTA_DV(a2)

; Calcul texture coords
  move.l  CRD_UL(a3),d5                 ; ui
  addi.l  #FIXP16_ROUND_UP,d5
  move.l  CRD_VL(a3),d6                 ; vi
  addi.l  #FIXP16_ROUND_UP,d6

; Horizontal clipping
  cmp.l   CRD_LCLIP(a3),d3
  bge.s   .NoLeftClip
  move.l  CRD_LCLIP(a3),d7
  sub.l   d3,d7
  move.l  DELTA_DU(a2),d3
  muls.l  d7,d3
  add.l   d3,d5
  move.l  DELTA_DV(a2),d3
  muls.l  d7,d3
  add.l   d3,d6
  move.l  CRD_LCLIP(a3),d3
  move.l  d4,d7
  sub.l   d3,d7
.NoLeftClip:
  cmp.l   CRD_RCLIP(a3),d4
  blt.s   .NoRightClip
  move.l  CRD_RCLIP(a3),d7
  subq.l  #1,d7
  sub.l   d3,d7
.NoRightClip:

; Calcul start address
  movea.l a1,a4
  adda.l  CRD_LINE(a3),a4
  adda.l  d3,a4                         ; start address

; Draw the line
.NextTexel:
; Write the texel
  move.l  d6,d4
  swap    d4
  mulu.w  d1,d4                         ; (vi >> FIXP16_SHIFT) * texture_width
  move.l  d5,d3
  swap    d3
  ext.l   d3
  add.l   d3,d4                         ; + ui >> FIXP16_SHIFT
  move.b  0(a0,d4.l),d3
  cmp.b   CRD_TCOLOR(a3),d3
  beq.s   .Transparent
  move.b  d3,(a4)
.Transparent:
  adda.l  #1,a4
; Interpolate u & v
  add.l   DELTA_DU(a2),d5
  add.l   DELTA_DV(a2),d6
  dbf     d7,.NextTexel

.Interpolate:
; Interpolate next points
  move.l  DELTA_DXDYL(a2),d3
  add.l   d3,CRD_XL(a3)
  move.l  DELTA_DUDYL(a2),d4
  add.l   d4,CRD_UL(a3)
  move.l  DELTA_DVDYL(a2),d5
  add.l   d5,CRD_VL(a3)
  move.l  DELTA_DXDYR(a2),d3
  add.l   d3,CRD_XR(a3)
  move.l  DELTA_DUDYR(a2),d4
  add.l   d4,CRD_UR(a3)
  move.l  DELTA_DVDYR(a2),d5
  add.l   d5,CRD_VR(a3)

; Next line address
  add.l   d2,CRD_LINE(a3)

  dbf     d0,.MapNextLine

.EndDraw:
  movem.l (sp)+,d1-d7/a0-a6
  move.l  #-1,d0
  rts

;--------------------------------------
; Map a 16bits transparent texture
;
; @in d0.l number of lines to map
; @in a0.l texture address
; @in d1.l texture width
; @in a1.l bitmap address
; @in d2.l bitmap width
; @in a2.l deltas array
; @in a3.l coords array
;
; @out d0.l operation success
;--------------------------------------
  xdef _SAGE_FastMap16BitsTransparent

_SAGE_FastMap16BitsTransparent:
  movem.l d1-d7/a0-a6,-(sp)
  tst.l   d0                            ; no lines ?
  ble     .EndDraw

  move.l  CRD_LINE(a3),d7
  lsl.l   #1,d7
  move.l  d7,CRD_LINE(a3)               ; 16bits

  subq.l  #1,d0
.MapNextLine:

; Calcul edge coords
  move.l  CRD_XL(a3),d3                 ; xs
  addi.l  #FIXP16_ROUND_UP,d3
  swap    d3
  ext.l   d3
  move.l  CRD_XR(a3),d4                 ; xe
  addi.l  #FIXP16_ROUND_UP,d4
  swap    d4
  ext.l   d4

; Check for left/right clipping
.PointsOnScreen:
  cmp.l   CRD_RCLIP(a3),d3
  bge    .Interpolate
  cmp.l   CRD_LCLIP(a3),d4
  blt    .Interpolate

; Calcul texture interpolation
  move.l  CRD_UR(a3),d5
  sub.l   CRD_UL(a3),d5
  move.l  CRD_VR(a3),d6
  sub.l   CRD_VL(a3),d6
  move.l  d4,d7
  sub.l   d3,d7                         ; dx
  ble.s   .DxNegative
  divs.l  d7,d5                         ; du
  divs.l  d7,d6                         ; dv
.DxNegative:
  move.l  d5,DELTA_DU(a2)
  move.l  d6,DELTA_DV(a2)

; Calcul texture coords
  move.l  CRD_UL(a3),d5                 ; ui
  addi.l  #FIXP16_ROUND_UP,d5
  move.l  CRD_VL(a3),d6                 ; vi
  addi.l  #FIXP16_ROUND_UP,d6

; Horizontal clipping
  cmp.l   CRD_LCLIP(a3),d3
  bge.s   .NoLeftClip
  move.l  CRD_LCLIP(a3),d7
  sub.l   d3,d7
  move.l  DELTA_DU(a2),d3
  muls.l  d7,d3
  add.l   d3,d5
  move.l  DELTA_DV(a2),d3
  muls.l  d7,d3
  add.l   d3,d6
  move.l  CRD_LCLIP(a3),d3
  move.l  d4,d7
  sub.l   d3,d7
.NoLeftClip:
  cmp.l   CRD_RCLIP(a3),d4
  blt.s   .NoRightClip
  move.l  CRD_RCLIP(a3),d7
  subq.l  #1,d7
  sub.l   d3,d7
.NoRightClip:

; Calcul start address
  movea.l a1,a4
  adda.l  CRD_LINE(a3),a4
  lsl.l   #1,d3                         ; 16bits
  adda.l  d3,a4                         ; start address

; Draw the line
.NextTexel:
; Write the texel
  move.l  d6,d4
  swap    d4
  ext.l   d4
  mulu.l  d1,d4                         ; (vi >> FIXP16_SHIFT) * texture_width
  move.l  d5,d3
  swap    d3
  ext.l   d3
  add.l   d3,d3                         ; 16bits
  add.l   d3,d4                         ; + ui >> FIXP16_SHIFT
  move.w  0(a0,d4.l),d3
  cmp.w   CRD_TCOLOR(a3),d3
  beq.s   .Transparent
  move.w  d3,(a4)
.Transparent:
  adda.l  #2,a4
; Interpolate u & v
  add.l   DELTA_DU(a2),d5
  add.l   DELTA_DV(a2),d6
  dbf     d7,.NextTexel

; Interpolate next points
.Interpolate:
  move.l  DELTA_DXDYL(a2),d3
  add.l   d3,CRD_XL(a3)
  move.l  DELTA_DUDYL(a2),d4
  add.l   d4,CRD_UL(a3)
  move.l  DELTA_DVDYL(a2),d5
  add.l   d5,CRD_VL(a3)
  move.l  DELTA_DXDYR(a2),d3
  add.l   d3,CRD_XR(a3)
  move.l  DELTA_DUDYR(a2),d4
  add.l   d4,CRD_UR(a3)
  move.l  DELTA_DVDYR(a2),d5
  add.l   d5,CRD_VR(a3)

; Next line address
  add.l   d2,CRD_LINE(a3)

  dbf     d0,.MapNextLine

.EndDraw:
  movem.l (sp)+,d1-d7/a0-a6
  move.l  #-1,d0
  rts

  END
