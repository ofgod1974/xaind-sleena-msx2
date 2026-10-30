#include "game.h"

typedef struct { u8 active,kind,x,y,vx,vy,age,face; } Shot;
#define SHOTS ((volatile Shot *)0xc400)
#define WEAPON RAM8(0xc500)
#define DOWN_HELD RAM8(0xc502)
#define FIRE_HELD RAM8(0xc503)
#define LIVES RAM8(0xc504)
#define POWER_Y RAM8(0xc507)
#define RANDOM RAM8(0xc50a)
#define SHOOT_POSE RAM8(0xc538)
#define BULLET RAM8(0xc00b)
#define SCORE_HUNDREDS RAM16(0xc534)
#define EXTEND_AT RAM16(0xc536)
static const u8 cooldowns[]={4,6,5,10,4};
static const u8 limits[]={3,2,6,1,9};
static const u8 speeds[]={5,2,5,4,5};
static const u8 muzzle[]={5,10,22};
static const u8 projectile_top[]={6,4,4,2,0};

static void sound(u8 id) { SFX_COMMAND=id; engine_sfx(); }

void game_stance(void) {
    u8 seed=RANDOM;
    if (SHOOT_POSE) --SHOOT_POSE;
    RANDOM=(seed>>1)^((seed&1)?0xb8:0);
    if (AIR) { STANCE=0; return; }
    if (JOY>=4 && JOY<7) {
        if (JOY==6) FACE=128;
        if (JOY==4) FACE=0;
        if (!DOWN_HELD) { DOWN_HELD=1; if (STANCE<2) ++STANCE; }
    } else {
        DOWN_HELD=0;
        if (JOY) STANCE=0;
    }
}

static void spawn(u8 kind,u8 dy,u8 offset) {
    u8 i,count=0;
    volatile Shot *s;
    for(i=0;i<9;++i) if(SHOTS[i].active && SHOTS[i].kind==kind) ++count;
    if(count>=limits[kind]) return;
    for(i=0;i<9;++i) if(!SHOTS[i].active) break;
    if(i==9) return;
    s=&SHOTS[i];
    s->active=1; s->kind=kind; s->face=FACE;
    s->x=PX+(FACE?(u8)-8:10);
    s->vx=FACE?(u8)-speeds[kind]:speeds[kind];
    s->vy=dy; s->age=kind==4?offset:0;
    s->y=PY+muzzle[STANCE]+projectile_top[kind]+offset;
}

static void fire_weapon(void) {
    u8 w=WEAPON;
    if(w>4) w=0;
    SHOOT_POSE=6; COOL=cooldowns[w];
    if(w==1) { spawn(0,0,0); spawn(1,(u8)-5,0); }
    else if(w==2) { spawn(2,0,0); spawn(2,(u8)-2,0); }
    else if(w==4) { spawn(4,0,0); spawn(4,0,(u8)-10); spawn(4,0,14); }
    else spawn(w,0,0);
    sound(1);
}

static u8 increment_bcd(u8 b) {
    ++b;
    if((b&15)==10) b+=6;
    return b;
}

static void award_hundred(void) {
    u8 b=increment_bcd(RAM8(0xc531));
    RAM8(0xc531)=b;
    if(!b) RAM8(0xc532)=increment_bcd(RAM8(0xc532));
    ++SCORE_HUNDREDS;
    if(SCORE_HUNDREDS==EXTEND_AT) {
        if(LIVES<9) ++LIVES;
        EXTEND_AT=EXTEND_AT==200?700:EXTEND_AT+700;
    }
}

static void destroy_enemy(void) {
    ENEMY=0;
    if(CARRIER) { CARRIER=0; POWER_ACTIVE=1; POWER_X=EX; POWER_Y=146; }
    award_hundred(); sound(2);
}

static void power_update(void) {
    if(!POWER_ACTIVE || (u8)(POWER_X-PX+14)>=30) return;
    if(POWER_Y>=(u8)(PY+32) || PY>=(u8)(POWER_Y+11)) return;
    POWER_ACTIVE=0; WEAPON=(RANDOM&3)+1; sound(3);
}

void game_weapons(void) {
    u8 i;
    if(!FIRE) FIRE_HELD=0;
    else if(!FIRE_HELD) { FIRE_HELD=1; if(!COOL) fire_weapon(); }
    BULLET=0;
    for(i=0;i<9;++i) {
        volatile Shot *s=&SHOTS[i];
        u8 old,x;
        if(!s->active) continue;
        BULLET=1;
        if(s->kind==5) { if(!--s->age) {s->active=0;continue;} }
        else {
            old=s->x; x=old+s->vx;
            if((s->vx&128)?x>=old:x<old) {s->active=0;continue;}
            if(x<14||x>=234) {s->active=0;continue;}
            s->x=x; s->y+=s->vy;
            if(s->y<24||s->y>=184) {s->active=0;continue;}
            if(s->kind==1) {
                if(!(++s->age&1)) ++s->vy;
                if(s->y>=152) {s->y=152;s->kind=5;s->age=8;sound(2);}
            }
        }
        if(!ENEMY || s->y<119 || (u8)(EX-s->x+14)>=30) continue;
        destroy_enemy();
        if(s->kind==3 || s->kind==5) continue;
        if(s->kind==1) {s->kind=5;s->age=8;sound(2);}
        else s->active=0;
    }
    power_update();
}

void game_lose_life(void) {
    u8 i;
    WEAPON=STANCE=AIR=VY=JUMP_COUNT=BULLET=0;
    for(i=0;i<9;++i) SHOTS[i].active=0;
    if(--LIVES) {HP=16;PY=128;SHIELD=120;}
    else {STATE=2;RESTART_ARMED=0;COOL=50;}
}
