#include <stdint.h>
#include <limits.h>
#include "print.h"

#include "tiny_mnist_model.h"
#include "test_image.h"
extern volatile int _test_start[];
int cnt = 0;
extern int32_t mac32(int32_t acc, int32_t x, int32_t y);

static int tiny_mnist_predict(const uint8_t *x) {
    int best_k = 0;
    int32_t best_score = INT32_MIN;

    for (int k = 0; k < TINY_MNIST_C; ++k) {
        int32_t acc = TINY_MNIST_B[k];

        for (int i = 0; i < TINY_MNIST_D; ++i) {
            acc = mac32(acc, (int32_t)TINY_MNIST_W[k][i], (int32_t)tiny_input_image[i]);
        }
        if (acc > best_score) {
            best_score = acc;
            best_k = k;
        }
        _test_start[cnt++] = acc;
        printf("class %d score = %d\n", k, acc);
        
    }

    return best_k;
}

int main(void) {
    printf("Tiny MNIST int inference\n");
    printf("Model: C=%d, D=%d, IMG_SIZE=%d\n",
           TINY_MNIST_C, TINY_MNIST_D, TINY_MNIST_IMG_SIZE);
    int digit = tiny_mnist_predict(tiny_input_image);
    _test_start[cnt++] = digit;
    printf("Result is %d\n", digit);
    return 0;
}
