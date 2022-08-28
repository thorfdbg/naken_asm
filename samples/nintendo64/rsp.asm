;; Simple Nintendo 64 sample.
;;
;; Copyright 2022 - By Michael Kohn
;; http://www.mikekohn.net/
;; mike@mikekohn.net
;;
;; RSP code for drawing / rotating triangles.

.n64_rsp

.include "nintendo64/rsp.inc"
.include "nintendo64/rdp.inc"

;; DMEM Format Is:
;;
;; byte   0: 0:Command/Signal | 1:Signal | 4,5:Offset | 6,7:Length
;; byte   8: X0, Y0, Z0
;; byte  16: X1, Y1, Z1
;; byte  24: X2, Y2, Z2
;; byte  32: rx, ry, rz
;; byte  40: dx, dy, dz
;; byte  48: fill color
;; -- Initialize screen.
;; byte  56: DP_OP_SET_COLOR_IMAGE
;; byte  64: DP_OP_SET_Z_IMAGE
;; byte  72: DP_OP_SET_SCISSOR
;; -- Polygons start.
;; byte  80: DP_OP_SYNC_PIPE
;; byte  88: DP_OP_SET_OTHER_MODES
;; byte  96: Polygon Color
;; byte 104: Polygon Data

;; v12: Temp for divide (holds the divisor and dividend).
;; v20: Temp (16.15 fraction reciprocal) in divide.
;; v21: Temp (16.15 integer reciprocal)for divide.
;; v22: Integer reciprocal for divide.
;; v23: Fraction reciprocal for divide.
;; v24: Integer answer for divide.
;; v25: Fraction answer for divide.
;;
;; $k0: Points to end of scratch pad (16 bytes currently).
;; $k0(0): Scratch pad.
;; $k0(8): Scratch pad.

.include "math.inc"

.org 0
start:
  ;; Set $k0 to point to scratchpad area of DMEM.
  li $k0, 0xff0

  ;; Set $v0 to a vector of 0's.
  vxor $v0, $v0, $v0

  ;; Set $v2[0]=2, $v2[1]=2 for DIVIDE macro.
  li $k1, 0x0002_0002
  sw $k1,  8($k0)
  llv $v2[0], 8($k0)

  ;; When DP_END_REG is written to, if it doesn't equal to DP_START_REG
  ;; it will start the RDP executing commands.
  ;; 0x000a = Set Freeze, Set DMEM DMA.
  li $t0, 0x000a
  mtc0 $t0, RSP_CP0_CMD_STATUS
  mtc0 $0, RSP_CP0_CMD_START
  mtc0 $0, RSP_CP0_CMD_END

main:
  ;; Wait until command byte (offset 0) is no longer 0.
  lb $t0, 0($0)
  beq $t0, $0, main
  nop

  ;; Command 1: Call start_rdp only for screen setup.
  ;; Command 2: Directly call start_rdp.
  ;; Command 3: Calculate triangle and call start_rdp.
  ;; Command 4: Calculate rotation, projection, triangle, and start_dp.
  ;; Command 5: Draw rectangle.
  li $t1, 1
  beq $t0, $t1, command_1
  nop
  li $t1, 2
  beq $t0, $t1, command_2
  nop
  li $t1, 3
  beq $t0, $t1, command_3
  nop
  li $t1, 4
  beq $t0, $t1, command_4
  nop
  li $t1, 5
  beq $t0, $t1, command_5
  nop

  ;; Unknown command.
  b main
  sb $0, 0($0)
  nop

  ;; Screen setup, run RDP commands from offset 56 to 72.
command_1:
  li $t1, 56
  li $t2, 24
  jal start_rdp
  nop
  jal wait_for_rdp
  nop
  sb $0, 0($0)
  b main
  nop

  ;; Run RDP commands specified by user: Offset 4 is offset, offset 6 is length.
command_2:
  lh $t1, 4($0)
  lh $t2, 6($0)
  ;lw $t1, 4($0)
  ;andi $t2, $t1, 0xffff
  ;srl $t1, $t1, 16
  jal start_rdp
  nop
  jal wait_for_rdp
  nop
  sb $0, 0($0)
  b main
  nop

  ;; Calculate triangle and call start_rdp.
  ;; byte 104: [command] [ YL ] [ YM ]   [ YH ]
  ;; byte 112: [   XL, frac   ] [ DxLDy, frac ]
  ;; byte 120: [   XH, frac   ] [ DxHDy, frac ]
  ;; byte 128: [   XM, frac   ] [ DxMDy, frac ]
command_3:
  ;; Set DP_OP_SET_OTHER_MODES for retangle fill.
  li $t8, (DP_OP_SET_OTHER_MODES << 24) | (1 << 23)
  sw $t8, 88($0)
  li $t8, (1 << 31)
  sw $t8, 92($0)
  ;; Color: $t6
  li $t8, DP_OP_SET_BLEND_COLOR << 24
  lw $t9,  48($0)
  sw $t8,  96($0)
  sw $t9, 100($0)
  ;; Vertix 0: ($t0, $t1)
  ;; Vertix 1: ($t2, $t3)
  ;; Vertix 2: ($t4, $t5)
  lh $t0, 8($0)
  lh $t1, 10($0)
  lh $t2, 16($0)
  lh $t3, 18($0)
  lh $t4, 24($0)
  lh $t5, 26($0)
  ;; Sort vertex so y values go from top to bottom.
  ;; if (y2 < y1) { swap; }
  slt $t8, $t5, $t3
  beq $t8, $0, command_3_skip_swap_0
  nop
  move $t8, $t2
  move $t9, $t3
  move $t2, $t4
  move $t3, $t5
  move $t4, $t8
  move $t5, $t9
command_3_skip_swap_0:
  ;; if (y1 < y0) { swap; }
  slt $t8, $t3, $t1
  beq $t8, $0, command_3_skip_swap_1
  nop
  move $t8, $t0
  move $t9, $t1
  move $t0, $t2
  move $t1, $t3
  move $t2, $t8
  move $t3, $t9
command_3_skip_swap_1:
  ;; if (y2 < y1) { swap; }
  slt $t8, $t5, $t3
  beq $t8, $0, command_3_skip_swap_2
  nop
  move $t8, $t2
  move $t9, $t3
  move $t2, $t4
  move $t3, $t5
  move $t4, $t8
  move $t5, $t9
command_3_skip_swap_2:
  ;; When y0 == y1, it can create a division by 0.
  bne $t1, $t3, command_3_not_div_0
  nop
  addiu $t3, $t3, 1
command_3_not_div_0:
  ;; Middle vertex leans to the right (left_major).
  ;; $t6 = is_left_major = x1 > x0 ? 1 : 0;
  slt $t6, $t0, $t2
  ;; Set command_byte=8, left_major=($t6 << 7), level=0, tile=0.
  li $t8, DP_OP_TRIANGLE_NON_SHADED << 8
  sll $t6, $t6, 7
  or $t8, $t8, $t6
  sh $t8, 104($0)
  ;; Store YL ($t5), YM ($t3), YH ($t1) as 11.2.
  sll $at, $t5, 2
  sh $at, 106($0)
  sll $at, $t3, 2
  sh $at, 108($0)
  sll $at, $t1, 2
  sh $at, 110($0)
  ;; Slope: y = dy/dx * x + y0
  ;; Inverse Slope: x = dx/dy * y + x0
  ;; $s0 = dx_h = x0 - x2;
  ;; $s1 = dx_m = x0 - x1;
  ;; $s2 = dx_l = x1 - x2;
  subu $s0, $t0, $t4
  subu $s1, $t0, $t2
  subu $s2, $t2, $t4
  ;; $s3 = dy_h = y0 - y2;
  ;; $s4 = dy_m = y0 - y1;
  ;; $s5 = dy_l = y1 - y2;
  subu $s3, $t1, $t5
  subu $s4, $t1, $t3
  subu $s5, $t3, $t5
  ;; if (dy_h == 0) { dy_h = 1 << 4; }
  ;; if (dy_m == 0) { dy_m = 1 << 4; }
  ;; if (dy_l == 0) { dy_l = 1; }
  bne $s3, $0, command_3_dy_h_not_0
  nop
  li $s3, 1 << 4
command_3_dy_h_not_0:
  bne $s4, $0, command_3_dy_m_not_0
  nop
  li $s4, 1 << 4
command_3_dy_m_not_0:
  bne $s5, $0, command_3_dy_l_not_0
  nop
  li $s5, 1
command_3_dy_l_not_0:

  ;; Shift by 14 to convert from 14.2 to 16.16 (not quite, but good enough).
  sll $s0, $s0, 16
  sll $s1, $s1, 16
  sll $s2, $s2, 16
  sll $s3, $s3, 16
  sll $s4, $s4, 16
  sll $s5, $s5, 16

  ;; $s0 = dxhdy = dx_h / dy_h;  ($s0 / $s3)
  sw $s0, 8($k0)
  sw $s3, 12($k0)
  DIVIDE_I_IF
  lw $s0, 8($k0)

  ;; $s1 = dxmdy = dx_m / dy_m;  ($s1 / $s4)
  sw $s1, 8($k0)
  sw $s4, 12($k0)
  DIVIDE_I_IF
  lw $s1, 8($k0)

  ;; $s2 = dxldy = dx_l / dy_l;  ($s2 / $s5)
  sw $s2, 8($k0)
  sw $s5, 12($k0)
  DIVIDE_I_IF
  lw $s2, 8($k0)

  sw $s2, 116($0)
  sw $s0, 124($0)
  sw $s1, 132($0)

  ;; Convert x0, x1, x2 to 16.16 (a little off, but good enough).
  sll $t7, $t0, 16
  ;;sll $t8, $t2, 16
  ;;sll $t9, $t4, 16

  ;; $s3 = yh_fraction = y0 & 0xf;
  sll $s3, $t1, 16
  andi $s3, $s3, 0xffff

  ;; $s5 = dxhdy * yh_fraction.
  sw $s0, 8($k0)
  sw $s3, 12($k0)
  MULTIPLY_IFxF
  lw $s5, 8($k0)

  ;; $s4 = dxmdy * yh_fraction.
  sw $s1, 8($k0)
  sw $s3, 12($k0)
  MULTIPLY_IFxF
  lw $s4, 8($k0)

  ;; xh = x0 - (dxhdy * yh_fraction);
  subu $t8, $t7, $s5
  sw $t8, 120($0)

  ;; xm = x0 - (dxmdy * yh_fraction);
  subu $t8, $t7, $s4
  sw $t8, 128($0)

  ;; xl = x0 + (dxmdy * (y1 - y0));
  sll $t1, $t1, 16
  sll $t3, $t3, 16
  subu $t8, $t3, $t1
  sw $s1, 8($k0)
  sw $t8, 12($k0)
  MULTIPLY_IFxI
  lw $s4, 8($k0)
  addu $t8, $t7, $s4
  sw $t8, 112($0)

  ;; Execute it.
  li $t1, 80
  li $t2, 56
  jal start_rdp
  nop
  jal wait_for_rdp
  nop

  sb $0, 0($0)
  b main
  nop

command_4:
  ;; Rotate around X Axis.
  lh $v0, 32($0)
  beq $v0, $0, skip_rotate_x
  ;nop
  addiu $v1, $v0, 128
  andi $v1, $v1, 0x1ff
  sll $v0, $v0, 2
  sll $v1, $v1, 2

  addiu $v0, $v0, 1024
  addiu $v1, $v1, 1024

  ;; cos(r)
  llv $v12[0], 0($v0)
  ;; sin(r)
  llv $v13[0], 0($v1)

  ;; Build X rotational matrix
  ;; [ 1    0       0    ]
  ;; [ 0  cos(r) -sin(r) ]
  ;; [ 0  sin(r)  cos(r) ]
  ;; $v22 = [ Y0, Z0, Y1, Z1, Y2, Z2, 0, 0 ] <- s_int
  ;; $v12 = [ cos(r) int, cos(r) frac, 0, 0, 0, 0, 0, 0 ]
  ;; $v13 = [ sin(r) int, sin(r) frac, 0, 0, 0, 0, 0, 0 ]
  lsv $v22[0], 10($0)
  lsv $v22[2], 12($0)
  lsv $v22[4], 18($0)
  lsv $v22[6], 20($0)
  lsv $v22[8], 26($0)
  lsv $v22[10], 28($0)

  ;; I * IF = IF
  ;; vmudm res_frac, s_int,    t_frac
  ;; vmadh res_int,  s_int,    t_int
  ;; vmadn res_frac, dev_null, dev_null[0]
  vmudm $v25, $v22, $v12[1]
  vmadh $v24, $v22, $v12[0]
  vmadn $v25, $v0,  $v0

  vmudm $v27, $v22, $v13[1]
  vmadh $v26, $v22, $v13[0]
  vmadn $v27, $v0,  $v0

  ;; X0 = Y0 * cos(r) - Z0 * sin(r)
  ;; Y0 = Y0 * sin(r) + Z0 * cos(r)
  slv $v24[0], 0($k0)
  slv $v26[0], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 10($0)
  sh $t1, 12($0)

  ;; X1 = Y1 * cos(r) - Z1 * sin(r)
  ;; Y1 = Y1 * sin(r) + Z1 * cos(r)
  slv $v24[4], 0($k0)
  slv $v26[4], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 18($0)
  sh $t1, 20($0)

  ;; X2 = Y2 * cos(r) - Z2 * sin(r)
  ;; Y2 = Y2 * sin(r) + Z2 * cos(r)
  slv $v24[8], 0($k0)
  slv $v26[8], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 26($0)
  sh $t1, 28($0)
skip_rotate_x:

  ;; Rotate around Y Axis.
  lh $v0, 34($0)
  beq $v0, $0, skip_rotate_y
  ;nop
  addiu $v1, $v0, 128
  andi $v1, $v1, 0x1ff
  sll $v0, $v0, 2
  sll $v1, $v1, 2

  addiu $v0, $v0, 1024
  addiu $v1, $v1, 1024

  ;; cos(r)
  llv $v12[0], 0($v0)
  ;; sin(r)
  llv $v13[0], 0($v1)

  ;; Build Y rotational matrix
  ;; [  cos(r)  0   sin(r) ]
  ;; [   0      1     0    ]
  ;; [ -sin(r)  0   cos(r) ]
  ;; $v22 = [ X0, Z0, X1, Z1, X2, Z2, 0, 0 ] <- s_int
  ;; $v12 = [ cos(r) int, cos(r) frac, 0, 0, 0, 0, 0, 0 ]
  ;; $v13 = [ sin(r) int, sin(r) frac, 0, 0, 0, 0, 0, 0 ]
  lsv $v22[0], 8($0)
  lsv $v22[2], 12($0)
  lsv $v22[4], 16($0)
  lsv $v22[6], 20($0)
  lsv $v22[8], 24($0)
  lsv $v22[10], 28($0)

  ;; I * IF = IF
  ;; vmudm res_frac, s_int,    t_frac
  ;; vmadh res_int,  s_int,    t_int
  ;; vmadn res_frac, dev_null, dev_null[0]
  vmudm $v25, $v22, $v12[1]
  vmadh $v24, $v22, $v12[0]
  vmadn $v25, $v0,  $v0

  vmudm $v27, $v22, $v13[1]
  vmadh $v26, $v22, $v13[0]
  vmadn $v27, $v0,  $v0

  ;; X0 = X0 * cos(r) - Z0 * sin(r)
  ;; Y0 = X0 * sin(r) + Z0 * cos(r)
  slv $v24[0], 0($k0)
  slv $v26[0], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 8($0)
  sh $t1, 12($0)

  ;; X1 = X1 * cos(r) - Z1 * sin(r)
  ;; Y1 = X1 * sin(r) + Z1 * cos(r)
  slv $v24[4], 0($k0)
  slv $v26[4], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 16($0)
  sh $t1, 20($0)

  ;; X2 = X2 * cos(r) - Z2 * sin(r)
  ;; Y2 = X2 * sin(r) + Z2 * cos(r)
  slv $v24[8], 0($k0)
  slv $v26[8], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 24($0)
  sh $t1, 28($0)
skip_rotate_y:

  ;; Rotate around Z Axis.
  lh $v0, 36($0)
  beq $v0, $0, skip_rotate_z
  ;nop
  addiu $v1, $v0, 128
  andi $v1, $v1, 0x1ff
  sll $v0, $v0, 2
  sll $v1, $v1, 2

  addiu $v0, $v0, 1024
  addiu $v1, $v1, 1024

  ;; cos(r)
  llv $v12[0], 0($v0)
  ;; sin(r)
  llv $v13[0], 0($v1)

  ;; Build Z rotational matrix
  ;; [ cos(r) -sin(r)  0 ]
  ;; [ sin(r)  cos(r)  0 ]
  ;; [   0       0     1 ]
  ;; $v22 = [ X0, Y0, X1, Y1, X2, Y2, 0, 0 ] <- s_int
  ;; $v12 = [ cos(r) int, cos(r) frac, 0, 0, 0, 0, 0, 0 ]
  ;; $v13 = [ sin(r) int, sin(r) frac, 0, 0, 0, 0, 0, 0 ]
  llv $v22[0], 8($0)
  llv $v22[4], 16($0)
  llv $v22[8], 24($0)

  ;; I * IF = IF
  ;; vmudm res_frac, s_int,    t_frac
  ;; vmadh res_int,  s_int,    t_int
  ;; vmadn res_frac, dev_null, dev_null[0]
  vmudm $v25, $v22, $v12[1]
  vmadh $v24, $v22, $v12[0]
  vmadn $v25, $v0,  $v0

  vmudm $v27, $v22, $v13[1]
  vmadh $v26, $v22, $v13[0]
  vmadn $v27, $v0,  $v0

  ;; X0 = X0 * cos(r) - Y0 * sin(r)
  ;; Y0 = X0 * sin(r) + Y0 * cos(r)
  slv $v24[0], 0($k0)
  slv $v26[0], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 8($0)
  sh $t1, 10($0)

  ;; X1 = X1 * cos(r) - Y1 * sin(r)
  ;; Y1 = X1 * sin(r) + Y1 * cos(r)
  slv $v24[4], 0($k0)
  slv $v26[4], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 16($0)
  sh $t1, 18($0)

  ;; X2 = X2 * cos(r) - Y2 * sin(r)
  ;; Y2 = X2 * sin(r) + Y2 * cos(r)
  slv $v24[8], 0($k0)
  slv $v26[8], 4($k0)
  lh $a0, 0($k0) ; X * cos(r)
  lh $a1, 2($k0) ; Y * cos(r)
  lh $a2, 4($k0) ; X * sin(r)
  lh $a3, 6($k0) ; Y * sin(r)
  subu $t0, $a0, $a3
  addu $t1, $a2, $a1
  sh $t0, 24($0)
  sh $t1, 26($0)
skip_rotate_z:

  ;; Translation to dx, dy, dz.
  lh $t0, 40($0)
  lh $t1, 42($0)
  lh $t3, 8($0)
  lh $t4, 16($0)
  lh $t5, 24($0)
  add $t3, $t3, $t0
  add $t4, $t4, $t0
  add $t5, $t5, $t0
  sh $t3, 8($0)
  sh $t4, 16($0)
  sh $t5, 24($0)
  lh $t3, 10($0)
  lh $t4, 18($0)
  lh $t5, 26($0)
  add $t3, $t3, $t1
  add $t4, $t4, $t1
  add $t5, $t5, $t1
  sh $t3, 10($0)
  sh $t4, 18($0)
  sh $t5, 26($0)
  b command_3
  nop

  ;; Draw rectangle.
command_5:
  ;; Set DP_OP_SET_OTHER_MODES for retangle fill.
  li $t8, (DP_OP_SET_OTHER_MODES << 24) | (1 << 23) | (3 << 20)
  sw $t8, 88($0)
  ;; Set Fill Color Command: convert R, G, B to (RGBA << 16) | RGBA.
  li $t4, DP_OP_SET_FILL_COLOR << 24
  lb $t0, 48($0)
  lb $t1, 49($0)
  lb $t2, 50($0)
  srl $t0, $t0, 3
  srl $t1, $t1, 3
  srl $t2, $t2, 3
  sll $t0, $t0, 11
  sll $t1, $t1, 6
  sll $t2, $t2, 1
  or $t0, $t0, $t1
  or $t0, $t0, $t2
  sh $t0, 100($0)
  sh $t0, 102($0)
  sw $t4, 96($0)
  ;; Set Fill Rectangle Command.
  li $t4, DP_OP_FILL_RECTANGLE
  lh $t0, 8($0)
  lh $t1, 10($0)
  lh $t2, 16($0)
  lh $t3, 18($0)
  ;; Convert 12.4 fixed point to 10.2.
  srl $t0, $t0, 2
  srl $t1, $t1, 2
  srl $t2, $t2, 2
  srl $t3, $t3, 2
  ;; $t2 = XL
  ;; $t3 = YL
  sll $t2, $t2, 12
  or $t3, $t3, $t2
  ;; $t0 = XH
  ;; $t1 = YH
  sll $t0, $t0, 12
  or $t1, $t1, $t0
  sw $t3, 104($0)
  sw $t1, 108($0)
  sb $t4, 104($0)
  ;; Draw it.
  li $t1, 80
  li $t2, 4 * 8
  jal start_rdp
  nop
  jal wait_for_rdp
  nop
  sb $0, 0($0)
  b main
  nop

;; start_rdp($t1=offset, $t2=length)
start_rdp:
  ;; Wait until End/Start Valid are cleared.
start_rdp_wait_end_start_valid:
  mfc0 $t8, RSP_CP0_CMD_STATUS
  andi $t8, $t8, 0x640
  bne $t8, $0, start_rdp_wait_end_start_valid
  nop
  ;; 0x0004 = Clear Freeze.
  li $t0, 0x0004
  addu $t3, $t1, $t2
  mtc0 $t0, RSP_CP0_CMD_STATUS
  mtc0 $t1, RSP_CP0_CMD_START
  mtc0 $t3, RSP_CP0_CMD_END
  jr $ra
  nop

wait_for_rdp:
  mfc0 $t8, RSP_CP0_CMD_END
wait_for_rdp_loop:
  mfc0 $t9, RSP_CP0_CMD_CURRENT
  bne $t8, $t9, wait_for_rdp_loop
  nop
  jr $ra
  nop

while_1:
  b while_1
  nop

;; FIXME: Can delete this stuff later, but wanted it so some code could
;; be run and the result viewed in Mame's debugger to see how things work.

test_mul:
;; 5.5 * 6.5  35.75  0x0023_c000
;li $v0, (5 << 16) | 0x7fff
;li $v1, (6 << 16) | 0x7fff
;; 6 * 0.4 = 2.4
;li $v0, 0x6666
;li $v1, (6 << 16) | 0x7fff
;sw $v0, 8($k0)
;sw $v1, 12($k0)
;MULTIPLY_IFxI
;lw $at, 8($k0)
  jr $ra
  nop

test_div:
;; 6.5 / -2.5 = -2.40
;; DEBUG
;li $v0, (6 << 16) | 0x8000
;li $v1, (2 << 16) | 0x8000
;subu $v1, $0, $v1
;sw $v0, 8($k0)
;sw $v1, 12($k0)
;DIVIDE_I_IF
;lw $at, 8($k0)
  jr $ra
  nop

test_mul_vectored:
;li $t0, 0x0002_0002
;li $t1, 0x0004_0004
;sw $t0, 8($k0)
;sw $t1, 12($k0)

;llv $v13[0],  8($k0)
;llv $v13[4],  8($k0)
;llv $v13[8],  8($k0)
;llv $v13[12], 8($k0)
;llv $v14[0],  12($k0)
;llv $v14[4],  12($k0)
;llv $v14[8],  12($k0)
;llv $v14[12], 12($k0)
;vmudn $v13, $v13, $v14
  jr $ra
  nop

