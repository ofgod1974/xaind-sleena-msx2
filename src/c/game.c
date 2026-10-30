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
        FACE = 0;
        WALKING = 1;
        if (PX < 112) PX += 2;
        else {
            ++CAMERA;
            --EX;
            if (POWER_ACTIVE && --POWER_X < 8) POWER_ACTIVE = 0;
            /* Legacy demonstration boundary, not an arcade stage ending. */
            if (CAMERA >= 1024) {
                STATE = 1;
                RESTART_ARMED = 0;
                COOL = 50;
            }
        }
    } else if (JOY >= 6 && JOY <= 8) {
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
    /* Kept only for regression testing while arcade encounters are captured. */
    if (!ENEMY) {
        if (!(TICKS & 31)) {
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
    if (!CARRIER && !(TICKS & 63) && ENEMY && !EB) {
        EB = 1;
        EBX = EX;
    }
    if (EB) {
        u8 before = EBX;
        EBX -= 4;
        if (before < 4) EB = 0;
    }
}

static void collide_player(void) {
    u8 damage = 0;
    if (SHIELD || PY < 106) return;
    if (ENEMY && (u8)(EX - PX + 12) < 24) damage = 8;
    else if (EB && (u8)(EBX - PX + 4) < 20) {
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
    jump_player();
    game_weapons();
    demo_enemies();
    collide_player();
}
