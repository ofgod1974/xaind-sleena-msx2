; SCREEN 5 hidden-page compositor, eight bounded jobs per transaction.
; R#23 handles the full vertical camera; advances at most two pixels per render.
build_active EQU $c0a0 ; 0 idle, 1 composing, 2 complete
build_group EQU $c0a1
build_x EQU $c0a2
build_y EQU $c0a4
scroll_y EQU $c0a5
scroll_next_y EQU $c0a6
build_dx EQU $c0a7
build_dy EQU $c0a8
build_dest_x EQU $c0a9
build_width EQU $c0aa
build_old_back EQU $c0ab
render_old_back EQU $c0ad
patch_end EQU $c0b0
patch_y_end EQU $c0b1
patch_count EQU $c0b2
build_old_y EQU $c0ac

scroll_pipeline:
    LD A,(scroll_y)
    LD B,A
    LD A,($c941)
    CP B
    LD A,B
    JR Z,.yready
    JR C,.down
    INC A
    LD C,A
    LD A,($c941)
    CP C
    LD A,C
    JR Z,.yready
    INC A
    JR .yready
.down:
    DEC A
    LD C,A
    LD A,($c941)
    CP C
    LD A,C
    JR Z,.yready
    DEC A
.yready:
    LD (scroll_y),A
    LD A,(build_active)
    OR A
    CALL Z,pipeline_begin
    LD A,(build_active)
    CP 1
    CALL Z,pipeline_step
    LD A,(build_active)
    CP 2
    RET NZ
    LD HL,(camera)
    LD DE,(build_x)
    OR A
    SBC HL,DE
    RET C
    LD HL,(build_x)
    LD (render_camera),HL
    LD A,(back)
    XOR 1
    LD (back),A
    XOR A
    LD (build_active),A
    RET
pipeline_begin:
    LD HL,(camera)
    LD DE,(render_camera)
    OR A
    SBC HL,DE
    LD A,H
    OR L
    RET Z
    LD HL,(render_camera)
    LD DE,16
    ADD HL,DE
    LD (build_x),HL
    LD A,16
    LD (build_dx),A
    XOR A
    LD (build_dy),A
    LD (build_y),A
    LD (build_group),A
    INC A
    LD (build_active),A
    RET

pipeline_step:
    LD A,(build_group)
    LD B,A
    ADD A,A
    ADD A,A
    LD C,A
    LD A,B
    RRCA
    RRCA
    RRCA
    AND $e0
    SUB C
    ADD A,8
    LD (build_dest_x),A
    LD A,28
    LD (build_width),A
    LD A,(build_group)
    CP 7
    JR NZ,.command
    LD A,44
    LD (build_width),A
.command:
    CALL blankcmd
    LD A,(back)
    LD (cmd+3),A
    XOR 1
    LD (cmd+7),A
    LD A,(build_dest_x)
    LD (cmd+4),A
    LD B,A
    LD A,(build_dx)
    ADD A,B
    LD (cmd),A
    LD A,28
.width:
    LD (cmd+8),A
    OR A
    JR Z,.nocopy
    LD A,(build_dy)
    BIT 7,A
    JR NZ,.shiftup
    LD B,A
    LD A,24
    LD (cmd+2),A
    ADD A,B
    LD (cmd+6),A
    JR .height
.shiftup:
    NEG
    LD B,A
    LD A,24
    LD (cmd+6),A
    ADD A,B
    LD (cmd+2),A
.height:
    LD A,160
    SUB B
    LD (cmd+10),A
    CALL docmd
    CALL waitvdp
.nocopy:
    LD A,(back)
    LD (build_old_back),A
    XOR 1
    LD (back),A
    LD A,(vertical_coarse)
    LD (build_old_y),A
    LD A,(build_y)
    LD (vertical_coarse),A
    LD A,(build_dy)
    OR A
    JR Z,.right
    BIT 7,A
    JR NZ,.bottom
    LD (rowcount),A
    LD A,24
    JR .rows
.bottom:
    NEG
    LD (rowcount),A
    LD B,A
    LD A,184
    SUB B
.rows:
    LD (rowy),A
    LD A,(build_dest_x)
    LD (savedx),A
    LD A,(build_width)
    LD (savedwidth),A
    CALL .source_x
    CALL level_copy_rect
.right:
    LD A,(build_dx)
    OR A
    JR Z,.done
    LD (savedwidth),A
    LD B,A
    LD A,248
    SUB B
    LD (savedx),A
    LD A,(build_group)
    LD B,A
    ADD A,A
    ADD A,A
    ADD A,B
    ADD A,A
    ADD A,A
    ADD A,24
    LD (rowy),A
    LD A,20
    LD (rowcount),A
    CALL .source_x
    CALL level_copy_rect
.done:
    CALL pipeline_black_margins
    CALL pipeline_patch_actors
    LD A,(build_old_y)
    LD (vertical_coarse),A
    LD A,(build_old_back)
    LD (back),A
    LD A,(build_group)
    INC A
    LD (build_group),A
    CP 8
    RET C
    LD A,(back)
    XOR 1
    ADD A,A
    LD E,A
    LD D,0
    LD HL,$c0d2
    ADD HL,DE
    LD (HL),255
    INC HL
    LD (HL),0
    LD A,2
    LD (build_active),A
    RET
.source_x:
    LD A,(savedx)
    SUB 8
    LD E,A
    LD D,0
    LD HL,(build_x)
    ADD HL,DE
    LD (level_source_x),HL
    RET

; Copying the displayed page may also copy its actors. Repair only the
; intersections in the hidden strip; keep the displayed actors visible.
pipeline_patch_actors:
    LD IX,previous_player
    LD A,4
    LD (patch_count),A
.first:
    CALL pipeline_patch_rect
    LD DE,4
    ADD IX,DE
    LD A,(patch_count)
    DEC A
    LD (patch_count),A
    JR NZ,.first
    LD IX,shot_rects
    LD A,10
    LD (patch_count),A
.second:
    CALL pipeline_patch_rect
    LD DE,4
    ADD IX,DE
    LD A,(patch_count)
    DEC A
    LD (patch_count),A
    JR NZ,.second
    RET
pipeline_patch_rect:
    LD A,(IX+2)
    OR A
    RET Z
    LD A,(build_dx)
    LD C,A
    LD A,(IX+0)
    SUB C
    LD B,A
    LD A,(IX+2)
    ADD A,B
    LD (patch_end),A
    LD A,(build_dest_x)
    CP B
    JR NC,.left
    LD A,B
.left:
    LD (savedx),A
    LD B,A
    LD A,(patch_end)
    CP B
    RET C
    RET Z
    LD C,A
    LD A,(build_dest_x)
    LD B,A
    LD A,(build_width)
    ADD A,B
    CP C
    JR C,.right
    LD A,C
.right:
    LD B,A
    LD A,(savedx)
    LD C,A
    LD A,B
    SUB C
    RET C
    RET Z
    LD (savedwidth),A
    LD A,(build_dy)
    LD B,A
    LD A,(IX+1)
    ADD A,B
    LD C,A
    LD A,(IX+3)
    ADD A,C
    LD (patch_y_end),A
    LD A,C
    CP 24
    JR NC,.top
    LD A,24
.top:
    CP 184
    RET NC
    LD (rowy),A
    LD C,A
    LD A,(patch_y_end)
    CP 185
    JR C,.bottom
    LD A,184
.bottom:
    SUB C
    RET C
    RET Z
    LD (rowcount),A
    LD A,(savedx)
    SUB 8
    LD E,A
    LD D,0
    LD HL,(build_x)
    ADD HL,DE
    LD (level_source_x),HL
    JP level_copy_rect

; These are empty world rows, not graphics storage, in SCREEN 5.
pipeline_black_margins:
    LD A,(back)
    ADD A,A
    LD E,A
    LD D,0
    LD HL,$c0d2
    ADD HL,DE
    LD C,(HL)
    INC HL
    LD B,(HL)
    LD A,C
    CP B
    RET NC
    LD A,(build_dest_x)
    CP C
    JR NC,.left
    LD A,C
.left:
    LD (savedx),A
    LD C,A
    LD A,(build_width)
    LD E,A
    LD A,(build_dest_x)
    ADD A,E
    CP B
    JR C,.right
    LD A,B
.right:
    SUB C
    RET C
    RET Z
    LD (savedwidth),A
    CALL blankcmd
    LD A,(savedx)
    LD (cmd+4),A
    LD A,(savedwidth)
    LD (cmd+8),A
    LD A,24
    LD (cmd+10),A
    LD A,$c0
    LD (cmd+14),A
    CALL docmd
    CALL blankcmd
    LD A,(savedx)
    LD (cmd+4),A
    LD A,(savedwidth)
    LD (cmd+8),A
    LD A,184
    LD (cmd+6),A
    LD A,72
    LD (cmd+10),A
    LD A,$c0
    LD (cmd+14),A
    CALL docmd
    JP waitvdp
