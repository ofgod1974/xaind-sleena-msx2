; Arcade weapon IDs: normal=0, laser+grenade=1, photon=2, heavy=3, wide=4.
; Nine projectiles, each {active,kind,x,y,vx,vy,age,face}; dirty rectangles separate.
shots EQU $c400
shot_rects EQU $c600
weapon EQU $c500
stance EQU $c501
downheld EQU $c502
fireheld EQU $c503
lives EQU $c504
power_active EQU $c505
power_x EQU $c506
power_y EQU $c507
carrier EQU $c508
spawn_number EQU $c509
random_seed EQU $c50a
shot_kind EQU $c50b
shot_dy EQU $c50c
shot_offset EQU $c50d
shot_limit EQU $c50e
shot_count EQU $c50f
shot_index EQU $c510
shot_prev EQU $c512
power_rect EQU $c624
score_bcd EQU $c530
score_hundreds EQU $c534
extend_at EQU $c536
score_patterns EQU $c700
shoot_pose EQU $c538

gameplay_init:
    XOR A
    LD HL,$c400
    LD DE,$c401
    LD BC,$33f
    LD (HL),A
    LDIR
    LD A,3
    LD (lives),A
    LD A,(gameplay_config)
    CP 5
    JR C,.weaponok
    XOR A
.weaponok:
    LD (weapon),A
    LD A,16
    LD (hp),A
    LD A,$a7
    LD (random_seed),A
    LD HL,200
    LD (extend_at),HL
    RET

clear_shots:
    LD HL,shots
    LD DE,shots+1
    LD BC,71
    LD (HL),0
    LDIR
    XOR A
    LD (bullet),A
    RET

stance_update:
    LD A,(shoot_pose)
    OR A
    JR Z,.pose
    DEC A
    LD (shoot_pose),A
.pose:
    LD A,(random_seed)
    SRL A
    JR NC,.random
    XOR $b8
.random:
    LD (random_seed),A
    LD A,(air)
    OR A
    JR NZ,.standing
    LD A,(joy)
    CP 4
    JR C,.nodown
    CP 7
    JR NC,.nodown
    CP 6
    JR NZ,.downright
    LD A,128
    LD (face),A
    JR .downedge
.downright:
    CP 4
    JR NZ,.downedge
    XOR A
    LD (face),A
.downedge:
    LD A,(downheld)
    OR A
    RET NZ
    INC A
    LD (downheld),A
    LD A,(stance)
    CP 2
    RET NC
    INC A
    LD (stance),A
    RET
.nodown:
    XOR A
    LD (downheld),A
    LD A,(joy)
    OR A
    RET Z
.standing:
    XOR A
    LD (stance),A
    RET

weapons_update:
    LD A,(fire)
    OR A
    JR NZ,.pressed
    LD (fireheld),A
    JR .move
.pressed:
    LD A,(fireheld)
    OR A
    JR NZ,.move
    INC A
    LD (fireheld),A
    LD A,(cool)
    OR A
    JR NZ,.move
    CALL weapon_fire
.move:
    XOR A
    LD (bullet),A
    LD IX,shots
    LD B,9
.each:
    PUSH BC
    LD A,(IX+0)
    OR A
    JP Z,.next
    LD A,1
    LD (bullet),A
    LD A,(IX+1)
    CP 5
    JR Z,.explosion
    LD A,(IX+2)
    LD C,(IX+4)
    BIT 7,C
    JR NZ,.left
    ADD A,C
    JP C,.expire
    JR .xok
.left:
    ADD A,C
    JP NC,.expire
.xok:
    CP 14
    JP C,.expire
    CP 234
    JP NC,.expire
    LD (IX+2),A
    LD A,(IX+3)
    ADD A,(IX+5)
    CP 24
    JP C,.expire
    CP 184
    JP NC,.expire
    LD (IX+3),A
    LD A,(IX+1)
    CP 1
    JR NZ,.hit
    INC (IX+6)
    LD A,(IX+6)
    AND 1
    JR NZ,.ground
    INC (IX+5)
.ground:
    LD A,(IX+3)
    CP 152
    JR C,.hit
    LD (IX+3),152
    LD (IX+1),5
    LD (IX+6),8
    LD A,2
    CALL audio_sfx
    JR .hit
.explosion:
    DEC (IX+6)
    JR Z,.expire
.hit:
    LD A,(enemy)
    OR A
    JR Z,.next
    LD A,(IX+3)
    CP 119
    JR C,.next
    LD A,(ex)
    SUB (IX+2)
    ADD A,14
    CP 30
    JR NC,.next
    CALL enemy_destroyed
    LD A,(IX+1)
    CP 3
    JR Z,.next
    CP 5
    JR Z,.next
    CP 1
    JR NZ,.expire
    LD (IX+1),5
    LD (IX+6),8
    LD A,2
    CALL audio_sfx
    JR .next
.expire:
    LD (IX+0),0
.next:
    LD DE,8
    ADD IX,DE
    POP BC
    DEC B
    JP NZ,.each
    JP power_update

weapon_fire:
    LD A,6
    LD (shoot_pose),A
    LD A,(weapon)
    LD E,A
    LD D,0
    LD HL,weapon_cooldowns
    ADD HL,DE
    LD A,(HL)
    LD (cool),A
    LD A,(weapon)
    CP 1
    JR Z,.grenade
    CP 2
    JR Z,.photon
    CP 4
    JR Z,.wide
    LD (shot_kind),A
    XOR A
    LD (shot_dy),A
    LD (shot_offset),A
    CALL spawn_shot
    JP zap
.grenade:
    XOR A
    LD (shot_kind),A
    LD (shot_dy),A
    LD (shot_offset),A
    CALL spawn_shot
    LD A,1
    LD (shot_kind),A
    LD A,-5
    LD (shot_dy),A
    CALL spawn_shot
    JP zap
.photon:
    LD A,2
    LD (shot_kind),A
    XOR A
    LD (shot_dy),A
    LD (shot_offset),A
    CALL spawn_shot
    LD A,-2
    LD (shot_dy),A
    CALL spawn_shot
    JP zap
.wide:
    LD A,4
    LD (shot_kind),A
    XOR A
    LD (shot_dy),A
    LD (shot_offset),A
    CALL spawn_shot
    LD A,-10
    LD (shot_offset),A
    CALL spawn_shot
    LD A,14
    LD (shot_offset),A
    CALL spawn_shot
    JP zap

spawn_shot:
    LD A,(shot_kind)
    LD E,A
    LD D,0
    LD HL,weapon_limits
    ADD HL,DE
    LD A,(HL)
    LD (shot_limit),A
    LD IX,shots
    LD B,9
    LD C,0
.count:
    LD A,(IX+0)
    OR A
    JR Z,.countnext
    LD A,(shot_kind)
    CP (IX+1)
    JR NZ,.countnext
    INC C
.countnext:
    LD DE,8
    ADD IX,DE
    DJNZ .count
    LD A,(shot_limit)
    CP C
    RET Z
    RET C
    LD IX,shots
    LD B,9
.find:
    LD A,(IX+0)
    OR A
    JR Z,.found
    LD DE,8
    ADD IX,DE
    DJNZ .find
    RET
.found:
    LD (IX+0),1
    LD A,(shot_kind)
    LD (IX+1),A
    LD E,A
    LD D,0
    LD HL,weapon_speeds
    ADD HL,DE
    LD B,(HL)
    LD A,(face)
    LD (IX+7),A
    OR A
    LD A,(px)
    JR NZ,.faceleft
    ADD A,10
    JR .position
.faceleft:
    SUB 8
    PUSH AF
    XOR A
    SUB B
    LD B,A
    POP AF
.position:
    LD (IX+2),A
    LD (IX+4),B
    LD A,(shot_dy)
    LD (IX+5),A
    LD (IX+6),0
    LD A,(shot_kind)
    CP 4
    JR NZ,.muzzle
    LD A,(shot_offset)
    LD (IX+6),A
.muzzle:
    LD A,(stance)
    LD E,A
    LD D,0
    LD HL,muzzle_heights
    ADD HL,DE
    LD B,(HL)
    LD A,(shot_kind)
    LD E,A
    LD HL,projectile_top
    ADD HL,DE
    LD A,(HL)
    ADD A,B
    LD B,A
    LD A,(py)
    ADD A,B
    LD B,A
    LD A,(shot_offset)
    ADD A,B
    LD (IX+3),A
    RET

enemy_destroyed:
    XOR A
    LD (enemy),A
    LD A,(carrier)
    OR A
    JR Z,.points
    XOR A
    LD (carrier),A
    LD A,1
    LD (power_active),A
    LD A,(ex)
    LD (power_x),A
    LD A,146
    LD (power_y),A
.points:
    PUSH IX
    CALL award_hundred
    POP IX
    LD A,2
    JP audio_sfx

award_hundred:
    LD A,(score_bcd+1)
    ADD A,1
    DAA
    LD (score_bcd+1),A
    JR NC,.binary
    LD A,(score_bcd+2)
    ADD A,1
    DAA
    LD (score_bcd+2),A
.binary:
    LD HL,(score_hundreds)
    INC HL
    LD (score_hundreds),HL
    LD DE,(extend_at)
    OR A
    SBC HL,DE
    RET NZ
    LD A,(lives)
    CP 9
    JR NC,.threshold
    INC A
    LD (lives),A
.threshold:
    LD HL,700
    LD A,D
    OR A
    JR NZ,.addthreshold
    LD A,E
    CP 200
    JR Z,.storethreshold
.addthreshold:
    ADD HL,DE
.storethreshold:
    LD (extend_at),HL
    RET

power_update:
    LD A,(power_active)
    OR A
    RET Z
    LD A,(px)
    LD B,A
    LD A,(power_x)
    SUB B
    ADD A,14
    CP 30
    RET NC
    LD A,(py)
    ADD A,32
    LD B,A
    LD A,(power_y)
    CP B
    RET NC
    ADD A,11
    LD B,A
    LD A,(py)
    CP B
    RET NC
    XOR A
    LD (power_active),A
    LD A,(random_seed)
    AND 3
    INC A
    LD (weapon),A
    LD A,3
    JP audio_sfx

; On loss of one life the powered weapon is lost, not on every hit.
lose_life:
    XOR A
    LD (weapon),A
    LD (stance),A
    LD (air),A
    LD (vy),A
    LD (jumpcount),A
    CALL clear_shots
    LD A,(lives)
    DEC A
    LD (lives),A
    JR Z,.gameover
    LD A,16
    LD (hp),A
    LD A,128
    LD (py),A
    LD A,120
    LD (shield),A
    RET
.gameover:
    LD A,2
    LD (state),A
    XOR A
    LD (restartarmed),A
    LD A,50
    LD (cool),A
    RET

restore_weapons:
    LD IX,shot_rects
    LD B,9
.each:
    PUSH BC
    CALL restore_rect
    LD DE,4
    ADD IX,DE
    POP BC
    DJNZ .each
    LD IX,power_rect
    JP restore_rect

clear_weapon_rects:
    LD HL,shot_rects
    LD DE,shot_rects+1
    LD BC,35
    LD (HL),0
    LDIR
    XOR A
    LD (power_rect+2),A
    RET

draw_weapons:
    LD IX,shots
    LD HL,shot_rects
    LD (shot_prev),HL
    LD A,9
    LD (shot_count),A
.each:
    LD HL,(shot_prev)
    INC HL
    INC HL
    LD (HL),0
    LD A,(IX+0)
    OR A
    JP Z,.next
    CALL actorcmd
    LD A,(IX+1)
    CP 3
    JR C,.index
    CP 5
    JR Z,.explosion
    LD A,(IX+1)
    CP 3
    LD A,3
    JR Z,.direction
    LD A,5
    LD B,A
    LD A,(IX+6)
    OR A
    LD A,B
    JR Z,.direction
    LD A,8
.direction:
    LD B,A
    LD A,(IX+7)
    OR A
    LD A,B
    JR Z,.index
    INC A
.index:
    ADD A,A
    ADD A,A
    LD E,A
    LD D,0
    LD HL,weapon_rectangles
    ADD HL,DE
    LD A,(HL)
    LD (cmd),A
    INC HL
    LD A,(HL)
    ADD A,192
    LD (cmd+2),A
    INC HL
    LD A,(HL)
    LD (cmd+8),A
    INC HL
    LD A,(HL)
    LD (cmd+10),A
    JR .destination
.explosion:
    LD A,(IX+6)
    RRCA
    AND 3
    CP 3
    JR C,.frameok
    XOR A
.frameok:
    RLCA
    RLCA
    RLCA
    RLCA
    ADD A,192
    LD (cmd),A
    LD A,224
    LD (cmd+2),A
    LD HL,16
    LD (cmd+8),HL
    LD (cmd+10),HL
.destination:
    LD A,(IX+2)
    CALL compensate_x
    LD (cmd+4),A
    LD A,(IX+3)
    LD (cmd+6),A
    CALL clip_actor
    JR C,.next
    PUSH IX
    CALL docmd
    LD HL,(shot_prev)
    CALL remember_actor
    POP IX
.next:
    LD DE,8
    ADD IX,DE
    LD HL,(shot_prev)
    LD DE,4
    ADD HL,DE
    LD (shot_prev),HL
    LD A,(shot_count)
    DEC A
    LD (shot_count),A
    JP NZ,.each
    LD A,(carrier)
    OR A
    JR Z,.power
    LD A,(enemy)
    OR A
    JR Z,.power
    LD A,(previous_enemy+2)
    OR A
    JR Z,.power
    CALL power_command
    LD A,(ex)
    INC A
    CALL compensate_x
    LD (cmd+4),A
    LD A,145
    LD (cmd+6),A
    CALL clip_actor
    CALL NC,docmd
.power:
    XOR A
    LD (power_rect+2),A
    LD A,(power_active)
    OR A
    RET Z
    CALL power_command
    LD A,(power_x)
    CALL compensate_x
    LD (cmd+4),A
    LD A,(power_y)
    LD (cmd+6),A
    CALL clip_actor
    RET C
    CALL docmd
    LD HL,power_rect
    JP remember_actor

power_command:
    CALL actorcmd
    LD A,112
    LD (cmd),A
    LD A,224
    LD (cmd+2),A
    LD HL,14
    LD (cmd+8),HL
    LD HL,11
    LD (cmd+10),HL
    RET

upload_score:
    LD IX,score_bcd+2
    LD DE,score_patterns
    LD B,3
.pair:
    PUSH BC
    LD A,(IX+0)
    RRCA
    RRCA
    RRCA
    RRCA
    AND 15
    CALL .digit
    LD A,(IX+0)
    AND 15
    CALL .digit
    DEC IX
    POP BC
    DJNZ .pair
    LD HL,score_patterns
    LD DE,$3800+55*32
    LD BC,96
    JP hud_upload
.digit:
    LD L,A
    LD H,0
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    ADD HL,HL
    LD BC,hud_patterns+11*32
    ADD HL,BC
    LD BC,16
    LDIR
    RET

weapon_cooldowns: DB 4,6,5,10,4
weapon_limits: DB 3,2,6,1,9
weapon_speeds: DB 5,2,5,4,5
muzzle_heights: DB 5,10,22
projectile_top: DB 6,4,4,2,0
weapon_rectangles:
    INCLUDE "weapon-rects.asm"
