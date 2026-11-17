/* C gameplay core. Hardware rendering and the IRQ music driver stay in Z80.
 * This first migration preserves the 0.7 mechanics; demo encounters are
 * explicitly separate from the future captured arcade level data. */
#include "game.h"
#include "../../third_party/fusion-c/msx_fusion.h"

void game_input(void) {
    u8 direction = JoystickRead(0);
    JOY = direction ? direction : JoystickRead(1);
    FIRE = TriggerRead(0) | TriggerRead(1);
    JUMP_BUTTON = TriggerRead(3);
}

static void move_player(void) {
    WALKING = 0;
    if (STANCE) return;
    if (JOY >= 2 && JOY <= 4) {
        if(LEVEL_MODE==0xa5&&!level_can_move(1))return;
        FACE = 0;
        WALKING = 1;
        if (PX < 112 || CAMERA>=2512) {if(PX<224)PX+=2;}
        else {
            if(RAM8(0xc035)&&CAMERA>=VIEW_X+15&&!((BUILD_STATE==2||(BUILD_STATE==1&&RAM8(0xc0a1)==7))&&BUILD_X>VIEW_X&&BUILD_X<=CAMERA+1))return;
            ++CAMERA;
            --EX;
            if (POWER_ACTIVE) {--POWER_X;if(POWER_X<8)POWER_ACTIVE=0;}
        }
    } else if (JOY >= 6 && JOY <= 8) {
        if(LEVEL_MODE==0xa5&&!level_can_move(0))return;
        WALKING = 1;
        FACE = 128;
        if (PX >= 26) PX -= 2;
    }
}

static void jump_player(void) {
    u8 pressed = JOY == 1 || JOY == 2 || JOY == 8 || JUMP_BUTTON;
    if (!pressed) JUMP_HELD = 0;
    else if (!JUMP_HELD) {
        JUMP_HELD = 1;
        if (JUMP_COUNT < 2) {
            ++JUMP_COUNT;
            STANCE = 0;
            AIR = 1;
            VY = (u8)-7;
        }
    }
    if (!AIR) return;
    PY += VY;
    if (PY >= 192 || PY < 24) { PY = 24; VY = 0; }
    else if (!(TICKS & 1)) ++VY;
    if (!(VY & 128) && PY >= 128) {
        PY = 128;
        AIR = VY = JUMP_COUNT = 0;
    }
}

static void demo_enemies(void) {
    u8 floor;
    if(ENEMY==2){if(ENEMY_SMOKE)--ENEMY_SMOKE;else ENEMY=0;return;}
    /* Kept only for regression testing while arcade encounters are captured. */
    if (!ENEMY) {
        if (!(TICKS & 31)) {
            if(LEVEL_MODE==0xa5){
                floor=level_enemy_floor(CAMERA+232,0);
                if(!floor)return;
                ENEMY_Y=floor-32;
            }
            RAM8(0xc94d)=0;
            ENEMY = 1;
            CARRIER = (++SPAWN_NUMBER & 3) == 1;
            EX = 240;
        }
    } else if (CARRIER) {
        if ((u8)(EX - PX) < 80) {
            EX += 2;
            if (EX >= 239) EX = 238;
        }
    } else {
        if (!(TICKS & 1)) --EX;
        if (EX < 6) ENEMY = 0;
    }
    if(LEVEL_MODE==0xa5&&ENEMY==1){
        u16 cell=(CAMERA+EX-8)&0xfffe;
        if(RAM8(0xc94d)&&RAM16(0xc94a)==cell)floor=RAM8(0xc94c);
        else {floor=level_enemy_floor(CAMERA+EX-8,ENEMY_Y+32);RAM16(0xc94a)=cell;RAM8(0xc94c)=floor;RAM8(0xc94d)=1;}
        if(!floor){ENEMY=0;return;}
        ENEMY_Y=floor-32;
    }
    if (!CARRIER && !(TICKS & 63) && ENEMY && !EB) {
        EB = 1;
        EBX = EX;
        ENEMY_BULLET_Y=ENEMY_Y+14;
    }
    if (EB) {
        u8 before = EBX;
        EBX -= 4;
        if (before < 4) EB = 0;
    }
}

static void collide_player(void) {
    u8 damage = 0;
    if (TRAINER) { HP=16; return; }
    if (SHIELD) return;
    if (ENEMY==1 && (u8)(EX - PX + 12) < 24 && level_player_y()+30>ENEMY_Y && level_player_y()<ENEMY_Y+30) damage = 8;
    else if (EB && (u8)(EBX - PX + 4) < 20) {
        if(PY+30<ENEMY_BULLET_Y||PY>ENEMY_BULLET_Y)return;
        EB = 0;
        if (STANCE == 2) return;
        damage = 1;
    }
    if (!damage) return;
    SHIELD = 60;
    if (HP <= damage) { HP = 0; game_lose_life(); }
    else { HP -= damage; SFX_COMMAND = 2; engine_sfx(); }
}

void game_update(void) {
    if (COOL) --COOL;
    if (SHIELD) --SHIELD;
    game_stance();
    move_player();
    if(LEVEL_MODE==0xa5)level_physics();else jump_player();
    game_weapons();
    demo_enemies();
    collide_player();
    if(TRAINER)HP=16;
    if(LEVEL_MODE==0xa5&&!AIR){SAFE_CAMERA=CAMERA;SAFE_X=PX;SAFE_Y=PY;SAFE_CAMERA_Y=CAMERA_Y;SAFE_VALID=1;}
    if(LEVEL_MODE==0xa5){
        int screen=level_player_y()+CAMERA_Y;
        if(screen<96){if(CAMERA_Y<88)++CAMERA_Y;if(CAMERA_Y<88)++CAMERA_Y;}
        else if(screen>128&&CAMERA_Y){--CAMERA_Y;if(CAMERA_Y)--CAMERA_Y;}
    }
}
