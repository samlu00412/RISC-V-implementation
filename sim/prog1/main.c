// fp_sort.c
#include <stdint.h>
#include "print.h"
extern volatile float _test_start[];
extern int fp_less(const float *x, const float *y);

#define N 16

static float data[N] = {
    13.15625f,   // 421 / 32
    -2.34375f,   // -75 / 32
    7.328125f,   // 469 / 64
    41.796875f,  // 2675 / 64

    0.578125f,   // 37 / 64
    3.3125f,     // 53 / 16
    -10.375f,    // -83 / 8
    1.5625f,     // 25 / 16

    8.34375f,    // 267 / 32
    7.6875f,     // 123 / 16
    -3.40625f,   // -109 / 32
    100.171875f, // 6411 / 64

    2.28125f,    // 73 / 32
    -1.4375f,    // -23 / 16
    6.59375f,    // 211 / 32
    4.046875f    // 259 / 64
};

static float temp[N];

volatile float g_sum_lo;
volatile float g_sum_hi;

static void merge(float *a, float *tmp, int left, int mid, int right)
{
    int i = left;
    int j = mid;
    int k = left;

    while (i < mid && j < right) {
        if (fp_less(&a[i], &a[j])) {
            tmp[k++] = a[i++];
        } else {
            tmp[k++] = a[j++];
        }
    }

    while (i < mid) {
        tmp[k++] = a[i++];
    }

    while (j < right) {
        tmp[k++] = a[j++];
    }

    for (i = left; i < right; ++i) {
        a[i] = tmp[i];
    }
}

static void merge_sort_rec(float *a, float *tmp, int left, int right)
{
    if (right - left <= 1) {
        return;
    }

    int mid = left + (right - left) / 2;

    merge_sort_rec(a, tmp, left,  mid);
    merge_sort_rec(a, tmp, mid,   right);
    merge(a, tmp, left, mid, right);
}

void merge_sort(float *a, float *tmp, int n)
{
    merge_sort_rec(a, tmp, 0, n);
}

int main(void)
{
    merge_sort(data, temp, N);

    int mid = N / 2;
    float sum_lo = 0.0f;
    float sum_hi = 0.0f;
    printf("Sorting result:\n");
    for(int i = 0; i < N; i++){
        _test_start[i] = temp[i];
        printf("  %f\n", PF(temp[i]));
    }

    for (int i = 0; i < mid; ++i) {
        sum_lo += temp[i];
    }

    for (int i = mid; i < N; ++i) {
        sum_hi += temp[i];
    }

    float answer = sum_hi - sum_lo;
    printf("Answer: %f", PF(answer));
    _test_start[N] = answer;

    return 0;
}

