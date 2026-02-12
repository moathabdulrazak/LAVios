#ifndef GAME_PHYSICS_H
#define GAME_PHYSICS_H

#include <stdint.h>

// Free a string returned by any game_physics function.
void game_physics_free_string(char *ptr);

// RocketSol
char *rocketsol_generate_obstacles(const char *seed);
char *rocketsol_verify(const char *seed,
                       const char *inputs_json,
                       int32_t claimed_score,
                       const char *obstacle_data_json);

// DriveHard
char *drivehard_generate_obstacles(const char *seed);
char *drivehard_verify(const char *seed,
                       const char *inputs_json,
                       int32_t claimed_score,
                       const char *obstacle_data_json,
                       const char *breakdown_json);

// Warp
char *warp_generate_obstacles(const char *seed);
char *warp_verify(const char *seed,
                  const char *inputs_json,
                  int32_t claimed_score,
                  const char *obstacle_data_json,
                  const char *breakdown_json);

#endif
