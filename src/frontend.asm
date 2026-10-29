; Native SCREEN 8 title and arcade-style introduction, version 0.7.0.
front_scene EQU $c800
front_timer EQU $c802
front_held EQU $c804
front_row EQU $c805
front_column EQU $c806
front_attract EQU $c807
front_skip EQU $c808
front_title_limit EQU $c80a
front_hold_limit EQU $c80c
front_phase EQU $c810 ; 0 game, 1 load, 2 wipe, 3 type, 4 hold, 5 title

front_end:
    XOR A
    LD (front_held),A
    LD (front_attract),A
    LD (back),A
    LD HL,600
    LD DE,180
    LD A,($ffe8)
    AND 2
    JR Z,.limits
    LD HL,500
    LD DE,150
.limits:
    LD (front_title_limit),HL
    LD (front_hold_limit),DE
.title:
    LD A,1
    CALL front_song
    LD A,56
    LD (front_scene),A
    CALL front_load
    CALL front_wipe
    LD A,5
    LD (front_phase),A
    LD HL,0
    LD (front_timer),HL
.title_loop:
    CALL front_wait
    CALL front_button
    JR C,.start
    LD HL,(front_timer)
    INC HL
    LD (front_timer),HL
    LD A,L
    AND 31
    CALL Z,front_prompt
    LD HL,(front_timer)
    LD DE,(front_title_limit)
    OR A
    SBC HL,DE
    JR C,.title_loop
    LD A,1
    LD (front_attract),A
    JR .intro
.start:
    XOR A
    LD (front_attract),A
.intro:
    LD A,15
    CALL front_song
    LD A,58
    LD (front_scene),A
.page:
    CALL front_load
    CALL front_typewriter
    LD A,(front_skip)
    OR A
    JR NZ,.chosen
    LD HL,0
    LD (front_timer),HL
    LD A,4
    LD (front_phase),A
.hold:
    CALL front_wait
    CALL front_button
    JR C,.chosen
    LD HL,(front_timer)
    INC HL
    LD (front_timer),HL
    LD DE,(front_hold_limit)
    OR A
    SBC HL,DE
    JR C,.hold
    JR .next
.chosen:
    XOR A
    LD (front_attract),A
.next:
    LD A,(front_scene)
    ADD A,2
    LD (front_scene),A
    CP 64
    JR C,.page
    LD A,(front_attract)
    OR A
    JP NZ,.title
    ; Restore the gameplay background and hardware HUD before returning to main.
    CALL waitvdp
    DI
    LD A,$22
    OUT ($99),A
    LD A,$81
    OUT ($99),A
    CALL reset
    CALL scroll_init
    CALL waitvdp
    CALL sync_scroll
    LD A,32
    OUT ($99),A
    LD A,$88
    OUT ($99),A
    LD A,8
    OUT ($99),A
    LD A,$92
    OUT ($99),A
    LD A,$62
    OUT ($99),A
    LD A,$81
    OUT ($99),A
    LD A,(audio_config+1)
    CALL front_song
    XOR A
    LD (front_phase),A
    EI
    RET

front_song:
    DI
    CALL audio_song
    EI
    RET

front_wait:
    EI
    HALT
    CALL audio_poll
    RET

; New press of Space or joystick fire. Held input cannot skip multiple screens.
front_button:
    PUSH BC
    XOR A
    CALL $00d8
    LD B,A
    LD A,1
    PUSH BC
    CALL $00d8
    POP BC
    OR B
    JR NZ,.down
    LD (front_held),A
    POP BC
    OR A
    RET
.down:
    LD A,(front_held)
    OR A
    JR NZ,.held
    INC A
    LD (front_held),A
    POP BC
    SCF
    RET
.held:
    POP BC
    OR A
    RET

front_load:
    LD A,1
    LD (front_phase),A
    CALL waitvdp
    DI
    LD A,$22
    OUT ($99),A
    LD A,$81
    OUT ($99),A
    LD A,34 ; sprite disable, colour zero remains solid for the later HUD masks
    OUT ($99),A
    LD A,$88
    OUT ($99),A
    LD A,31 ; page 0
    OUT ($99),A
    LD A,$82
    OUT ($99),A
    XOR A
    OUT ($99),A
    LD A,$92
    OUT ($99),A
    LD A,(front_scene)
    CALL select_bank
    LD (streambank),A
    LD HL,$8000
    LD A,4 ; decompress to hidden page 1, leaving the sprite atlas intact
    CALL upload
    CALL blankcmd
    LD HL,256
    LD (cmd+8),HL
    LD HL,192
    LD (cmd+10),HL
    LD A,$c0
    LD (cmd+14),A
    CALL docmd
    CALL waitvdp
    CALL sync_scroll
    LD A,$62
    OUT ($99),A
    LD A,$81
    OUT ($99),A
    EI
    RET

front_wipe:
    LD A,2
    LD (front_phase),A
    XOR A
    LD (front_row),A
.row:
    CALL front_wait
    CALL blankcmd
    LD A,(front_row)
    LD (cmd+2),A
    LD (cmd+6),A
    LD A,1
    LD (cmd+3),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,12
    LD (cmd+10),HL
    CALL docmd
    LD A,(front_row)
    ADD A,12
    LD (front_row),A
    CP 192
    JR C,.row
    JP waitvdp

front_prompt:
    CALL blankcmd
    LD A,56
    LD (cmd),A
    LD (cmd+4),A
    LD A,124
    LD (cmd+2),A
    LD (cmd+6),A
    LD A,1
    LD (cmd+3),A
    LD HL,144
    LD (cmd+8),HL
    LD HL,10
    LD (cmd+10),HL
    LD A,(front_timer)
    AND 32
    JR Z,.copy
    LD A,$c0
    LD (cmd+14),A
.copy:
    JP docmd

front_typewriter:
    LD A,3
    LD (front_phase),A
    XOR A
    LD (front_skip),A
    CALL blankcmd
    LD A,1
    LD (cmd+3),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,104
    LD (cmd+10),HL
    CALL docmd
    CALL blankcmd
    LD A,152
    LD (cmd+2),A
    LD (cmd+6),A
    LD A,1
    LD (cmd+3),A
    LD HL,256
    LD (cmd+8),HL
    LD HL,40
    LD (cmd+10),HL
    CALL docmd
    LD A,112
    LD (front_row),A
.line:
    XOR A
    LD (front_column),A
.letter:
    CALL front_wait
    CALL front_button
    JR C,.skip
    CALL blankcmd
    LD A,(front_column)
    LD (cmd),A
    LD (cmd+4),A
    LD A,(front_row)
    LD (cmd+2),A
    LD (cmd+6),A
    LD A,1
    LD (cmd+3),A
    LD HL,6
    LD (cmd+8),HL
    LD HL,8
    LD (cmd+10),HL
    CALL docmd
    LD A,(front_column)
    ADD A,6
    LD (front_column),A
    CP 252
    JR C,.letter
    LD A,(front_row)
    ADD A,12
    LD (front_row),A
    CP 148
    JR C,.line
    RET
.skip:
    LD A,1
    LD (front_skip),A
    RET

front_version: DB "0.7.0",0
front_credit: DB "2026 - progetto di conversione di Lorenzo Moretti e Andrea D Dio (Associazione MSX Italia)",0
