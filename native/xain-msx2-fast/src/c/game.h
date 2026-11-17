#ifndef XAIN_GAME_H
#define XAIN_GAME_H
typedef unsigned char u8;
typedef signed char i8;
typedef unsigned int u16;
#define RAM8(a) (*(volatile u8 *)(a))
#define RAM16(a) (*(volatile u16 *)(a))
#define PX RAM8(0xc000)
#define PY RAM8(0xc001)
#define VY RAM8(0xc002)
#define AIR RAM8(0xc003)
#define TICKS RAM8(0xc004)
#define CAMERA RAM16(0xc005)
#define EX RAM8(0xc008)
#define ENEMY RAM8(0xc009)
#define COOL RAM8(0xc00c)
#define HP RAM8(0xc00d)
#define SHIELD RAM8(0xc00e)
#define STATE RAM8(0xc010)
#define JOY RAM8(0xc011)
#define EBX RAM8(0xc012)
#define EB RAM8(0xc013)
#define FACE RAM8(0xc014)
#define WALKING RAM8(0xc016)
#define FIRE RAM8(0xc018)
#define RESTART_ARMED RAM8(0xc020)
#define JUMP_HELD RAM8(0xc021)
#define JUMP_COUNT RAM8(0xc022)
#define STANCE RAM8(0xc501)
#define POWER_ACTIVE RAM8(0xc505)
#define POWER_X RAM8(0xc506)
#define CARRIER RAM8(0xc508)
#define SPAWN_NUMBER RAM8(0xc509)
#define SFX_COMMAND RAM8(0xc900)
#define JUMP_BUTTON RAM8(0xc901)
#define ENEMY_Y RAM8(0xc902)
#define ENEMY_BULLET_Y RAM8(0xc903)
#define ENEMY_SMOKE RAM8(0xc904)
#define VIEW_X RAM16(0xc088)
#define BUILD_STATE RAM8(0xc0a0)
#define BUILD_X RAM16(0xc0a2)
#define CAMERA_Y RAM8(0xc941)
#define TRAINER RAM8(0xc942)
#define SAFE_CAMERA RAM16(0xc944)
#define SAFE_X RAM8(0xc946)
#define SAFE_Y RAM8(0xc947)
#define SAFE_CAMERA_Y RAM8(0xc948)
#define SAFE_VALID RAM8(0xc949)
#define LEVEL_MODE RAM8(0xc940)
void engine_sfx(void);
void game_stance(void);
void game_weapons(void);
void game_lose_life(void);
void game_input(void);
void game_update(void);
void level_init(void);
void level_respawn(void);
void level_physics(void);
int level_player_y(void);
u8 level_enemy_floor(u16 x,u8 near_y);
u8 level_can_move(u8 right);
u8 level_solid(u16 x,u8 y);
u8 level_floor_at(u16 x);
#endif
