#include "game.h"
#include "level-data.h"

u8 level_floor_at(u16 x) {
    u8 col=x>>8;
    return col<12?level_floor[col]:192;
}

/* Original 4x4 collision cells, mapped to the 160-line MSX playing field.
 * Original direction/slope flags remain in level_shapes; this first resolver
 * uses the solid bit and samples the surface at native pixel steps. */
static const u8 solid_rows[]={0,0,0,0,8,12,12,14,14,14,14,14,12,12,12,14,15,15,15,15,1,3,3,3,3,3,7,7,7,7,7,7,0,0,0,12,8,12,14,14,0,0,0,7,3,7,7,7,0,14,14,15,0,0,0,15,0,7,7,15,14,14,14,14,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,15,0,0,0,12,12,12,12,12,0,0,0,15,15,15,15,15,0,0,0,15,15,0,0,0,0,15,15,0,0,14,14,0,15,15,15,15,0,0,0,3,3,3,3,3,0,0,14,15,0,0,15,15,0,0,7,7,0,14,14,0,0,15,15,0,0,7,7,0,15,15,15,15,15,15,15,15,15,15,15,15};
static const u8 solid_y[]={255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,8,9,11,12,14,15,17,18,20,21,23,24,26,27,29,30,32,33,35,36,38,39,41,42,44,45,47,48,50,51,53,54,56,57,59,60,62,63,65,66,68,69,71,72,74,75,77,78,80,81,83,84,86,87,89,90,92,93,95,96,98,99,101,102,104,105,107,108,110,111,113,114,116,117,119,120,122,123,125,126,128,129,131,132,134,135,137,138,140,141,143,144,146,147,149,150,152,153,155,156,158,159,161,162,164,165,167,168,170,171,173,174,176,177,179,180,182,183,185,186,188,189,191,192,194,195,197,198,200,201,203,204,206,207,209,210,212,213,215,216,218,219,221,222,224,225,227,228,230,231,233,234,236,237,239,240,242,243,245,246,255,255,255,255,255,255,255,255};
static const u8 solid_bits[]={1,2,4,8};
u8 level_solid(u16 x,u8 y) __naked {
    __asm
        ld hl,#2
        add hl,sp
        ld e,(hl)
        inc hl
        ld d,(hl)
        inc hl
        ld a,(hl)
        cp #192
        jr nc,00090$
        ld l,a
        ld h,#0
        ld bc,#_solid_y
        add hl,bc
        ld a,(hl)
        cp #255
        jr z,00090$
        push af
        ld a,d
        cp #10
        jr c,00091$
        jr nz,00092$
        ld a,e
        cp #208
        jr nc,00092$
00091$:
        pop af
        push af
        rlca
        rlca
        rlca
        rlca
        and #15
        ld b,a
        ld a,e
        and #240
        or b
        ld l,a
        ld h,d
        ld bc,#_level_cells
        add hl,bc
        ld l,(hl)
        ld h,#0
        add hl,hl
        add hl,hl
        pop af
        and #12
        rrca
        rrca
        or l
        ld l,a
        ld bc,#_solid_rows
        add hl,bc
        ld a,(hl)
        push af
        ld a,e
        and #12
        rrca
        rrca
        ld l,a
        ld h,#0
        ld bc,#_solid_bits
        add hl,bc
        ld b,(hl)
        pop af
        and b
        ld hl,#0
        ret z
        inc l
        ret
00092$:
        pop af
00090$:
        ld hl,#0
        ret
    __endasm;
}

void level_respawn(void) {
    CAMERA=0;CAMERA_Y=0;PX=96;PY=level_floor_at(96)-32;
    AIR=VY=JUMP_COUNT=JUMP_HELD=0;
    ENEMY=EB=CARRIER=POWER_ACTIVE=ENEMY_SMOKE=0;
    ENEMY_Y=125;ENEMY_BULLET_Y=140;
    RAM8(0xc035)=0; /* rebuild both pages after the camera teleports */
}

void level_init(void) {
    LEVEL_MODE=0xa5;SAFE_VALID=0;
    level_respawn();
}

/* PY wraps only in the small offscreen area above the viewport. */
int level_player_y(void) { return PY>=192?(int)PY-256:(int)PY; }

u8 level_enemy_floor(u16 x,u8 near_y) {
    u8 y,lo=near_y>8?near_y-8:32,hi=near_y+8;
    if(!near_y){lo=64;hi=157;}
    for(y=lo;y<=hi;++y) {
        if(y<32)continue;
        if((level_solid(x,y)||y==level_floor_at(x)) &&
           !level_solid(x,y-1)&&!level_solid(x,y-16)&&!level_solid(x,y-28)&&
           !level_solid(x-6,y-16)&&!level_solid(x+6,y-16)) return y;
    }
    return 0;
}

u8 level_can_move(u8 right) {
    u16 x=CAMERA+PX-16;
    int top=level_player_y();
    u8 step;
    x+=right?17:(u16)-2;
    if(!level_solid(x,(u8)(top+10))&&!level_solid(x,(u8)(top+30)))return 1;
    if(!AIR)for(step=1;step<=16;++step) {
        if(!level_solid(x,(u8)(top+10-step))&&
           !level_solid(x,(u8)(top+31-step))&&
           level_solid(x,(u8)(top+32-step))) {PY=(u8)(top-step);return 1;}
    }
    return 0;
}

void level_physics(void) {
    u8 pressed=JOY==1||JOY==2||JOY==8||JUMP_BUTTON;
    int old=level_player_y(),feet=old+32,y,next;
    u8 floor;
    u16 center=CAMERA+PX-8;
    if(!AIR && !level_solid(center,(u8)(feet+1)) && !level_solid(center-6,(u8)(feet+1)) && !level_solid(center+6,(u8)(feet+1)) && feet<level_floor_at(center)) {
        AIR=1;VY=0;
    }
    if(!pressed)JUMP_HELD=0;
    else if(!JUMP_HELD) {
        JUMP_HELD=1;
        if(JUMP_COUNT<2 && (!JUMP_COUNT || (VY&128))) {
            ++JUMP_COUNT;STANCE=0;AIR=1;VY=(u8)-7;
        }
    }
    if(!AIR || (TICKS&1))return;
    next=old+(i8)VY;
    /* Offscreen presentation limit must not cancel the remaining jump. */
    if(next< -64)next= -64;
    if(!(VY&128)) {
        floor=level_floor_at(center);
        for(y=feet;y<=next+32&&y<192;++y) {
            if((floor<184&&y>=floor)||level_solid(center,(u8)y)) {
                while(y>24&&level_solid(center,(u8)(y-1)))--y;
                PY=(u8)(y-32);VY=AIR=JUMP_COUNT=0;
                return;
            }
        }
    } else if(level_solid(center,(u8)(next+2))&&!level_solid(center,(u8)(old+2))) {
        next=old;VY=0;
    }
    if(next>155){HP=0;game_lose_life();return;}
    PY=(u8)next;
    if(!(TICKS&7))++VY;
}
