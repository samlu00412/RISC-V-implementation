#include <stdint.h>
#include "print.h"

#define HANOI_DISKS  5u
extern volatile int32_t _test_start[];

static uint32_t move_count = 0;

static void hanoi_move(unsigned int n, char from, char aux, char to)
{
    if (n == 0u) {
        return;
    }

    /* move n-1 from `from` to `aux` */
    hanoi_move(n - 1u, from, to, aux);

    /* one actual move */
    printf("Move disk %u from %c to %c\n", n, from, to);
    move_count++;

    /* move n-1 from `aux` to `to` */
    hanoi_move(n - 1u, aux, from, to);
}

int main(void)
{
    printf("Hanoi with %u disks:\n", (unsigned)HANOI_DISKS);

    hanoi_move(HANOI_DISKS, 'A', 'B', 'C');

    printf("Total moves: %u\n", (unsigned)move_count);
    _test_start[0] = move_count;

    return 0;
}