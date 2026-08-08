#include <stdint.h>
#include "print.h"
#include "maze_map.h"

extern volatile char _test_start[];

static char maze_work[MAZE_H][MAZE_W + 1];

static int16_t parent_x[MAZE_H][MAZE_W];
static int16_t parent_y[MAZE_H][MAZE_W];

static uint8_t visited[MAZE_H][MAZE_W];

#define MAX_CELLS (MAZE_W * MAZE_H)
static int16_t qx[MAX_CELLS];
static int16_t qy[MAX_CELLS];

static char path_moves[MAX_CELLS + 1];

static void copy_maze_to_work(void)
{
    for (int y = 0; y < MAZE_H; ++y) {
        for (int x = 0; x < MAZE_W; ++x) {
            maze_work[y][x] = g_maze[y][x];
        }
        maze_work[y][MAZE_W] = '\0';
    }
}

static void print_maze(const char *title)
{
    printf("%s\n", title);
    for (int y = 0; y < MAZE_H; ++y) {
        printf("%s\n", maze_work[y]);
    }
    printf("\n");
}

static int build_path_and_mark(int sx, int sy, int ex, int ey)
{
    int length = 0;
    int x = ex;
    int y = ey;

    while (!(x == sx && y == sy)) {
        int px = parent_x[y][x];
        int py = parent_y[y][x];

        int dx = x - px;
        int dy = y - py;
        char step;

        if (dx == 1) {
            step = 'R';
        } else if (dx == -1) {
            step = 'L';
        } else if (dy == 1) {
            step = 'D';
        } else {
            step = 'U';
        }

        if (length < MAX_CELLS) {
            path_moves[length] = step;
        }

        if (maze_work[y][x] == ' ') {
            maze_work[y][x] = '.';
        }

        x = px;
        y = py;
        ++length;
    }

    for (int i = 0; i < length / 2; ++i) {
        char tmp = path_moves[i];
        path_moves[i] = path_moves[length - 1 - i];
        path_moves[length - 1 - i] = tmp;
    }

    if (length < MAX_CELLS) {
        path_moves[length] = '\0';
    } else {
        path_moves[MAX_CELLS] = '\0';
    }

    return length;
}

static int solve_maze(int *out_sx, int *out_sy, int *out_ex, int *out_ey)
{
    int sx = -1, sy = -1;
    int ex = -1, ey = -1;

    // 1) Find S and E
    for (int y = 0; y < MAZE_H; ++y) {
        for (int x = 0; x < MAZE_W; ++x) {
            if (maze_work[y][x] == 'S') {
                sx = x;
                sy = y;
            } else if (maze_work[y][x] == 'E') {
                ex = x;
                ey = y;
            }
        }
    }

    if (sx < 0 || sy < 0) {
        printf("Error: no start (S) in maze.\n");
        return -1;
    }
    if (ex < 0 || ey < 0) {
        printf("Error: no exit (E) in maze.\n");
        return -2;
    }

    for (int y = 0; y < MAZE_H; ++y) {
        for (int x = 0; x < MAZE_W; ++x) {
            visited[y][x] = 0;
            parent_x[y][x] = -1;
            parent_y[y][x] = -1;
        }
    }

    int head = 0;
    int tail = 0;

    qx[tail] = (int16_t)sx;
    qy[tail] = (int16_t)sy;
    ++tail;

    visited[sy][sx] = 1;

    while (head != tail) {
        int x = qx[head];
        int y = qy[head];
        ++head;

        if (x == ex && y == ey) {
            break;
        }

        const int dx[4] = { 1, -1,  0,  0 };
        const int dy[4] = { 0,  0,  1, -1 };

        for (int dir = 0; dir < 4; ++dir) {
            int nx = x + dx[dir];
            int ny = y + dy[dir];

            if (nx < 0 || nx >= MAZE_W || ny < 0 || ny >= MAZE_H) {
                continue;
            }

            char c = maze_work[ny][nx];
            if (c == '#') {
                continue;
            }

            if (visited[ny][nx]) {
                continue;
            }

            visited[ny][nx] = 1;
            parent_x[ny][nx] = x;
            parent_y[ny][nx] = y;

            qx[tail] = (int16_t)nx;
            qy[tail] = (int16_t)ny;
            ++tail;
        }
    }

    if (!visited[ey][ex]) {
        printf("Maze has no solution.\n");
        return -3;
    }

    int path_len = build_path_and_mark(sx, sy, ex, ey);

    printf("Path length: %d steps\n", path_len);

    *out_sx = sx;
    *out_sy = sy;
    *out_ex = ex;
    *out_ey = ey;

    return 0;
}

int main(void)
{
    int sx, sy, ex, ey;

    copy_maze_to_work();

    print_maze("Original maze:");

    int ret = solve_maze(&sx, &sy, &ex, &ey);
    if (ret != 0) {
        printf("Solve failed, error = %d\n", ret);
        return 0;
    }

    print_maze("Solved maze ('.' is the path):");

    printf("Start : (%d, %d)\n", sx, sy);
    printf("Exit  : (%d, %d)\n", ex, ey);
    printf("Moves : %s\n", path_moves);

    volatile char *p = _test_start;
    int idx = 0;
    while (path_moves[idx] != '\0') {
        p[idx] = path_moves[idx];
        ++idx;
    }

    return 0;
}
