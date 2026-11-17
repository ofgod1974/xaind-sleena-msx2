trainer_poll:
    LD A,5
    CALL $0141
    CPL
    AND 2
    LD B,A
    LD A,7
    PUSH BC
    CALL $0141
    POP BC
    CPL
    AND 64
    OR B
    JR NZ,.pressed
    LD ($c943),A
    RET
.pressed:
    LD A,($c943)
    OR A
    RET NZ
    INC A
    LD ($c943),A
    LD A,($c942)
    XOR 1
    LD ($c942),A
    OR A
    RET Z
    LD A,16
    LD (hp),A
    XOR A
    LD (shield),A
    RET

checkpoint_bitmap:
    LD A,(back)
    PUSH AF
    XOR A
    LD (back),A
    CALL .page
    LD A,1
    LD (back),A
    CALL .page
    POP AF
    LD (back),A
    RET
.page:
    LD HL,(render_camera)
    LD (level_source_x),HL
    LD A,8
    LD (savedx),A
    LD A,240
    LD (savedwidth),A
    LD A,24
    LD (rowy),A
    LD A,160
    LD (rowcount),A
    JP level_copy_rect
