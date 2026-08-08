// main.c — host demo version (x86_64 / Linux / macOS)
// compile：gcc -O2 main.c -o tiny_demo

#include <stdint.h>
#include <limits.h>
#include "print.h"

#include "tiny_mnist_model.h"
#include "test_image.h"

extern int32_t mac32(int32_t acc, int32_t x, int32_t y);

static int tiny_mnist_predict(const uint8_t *x) {
    int best_k = 0;
    int32_t best_score = INT32_MIN;

    for (int k = 0; k < TINY_MNIST_C; ++k) {
        int32_t acc = TINY_MNIST_B[k];

        for (int i = 0; i < TINY_MNIST_D; ++i) {

             int32_t w   = (int32_t)TINY_MNIST_W[k][i];
            int32_t xin = (int32_t)tiny_input_image[i];  // 你原本就是用 global，我就照用

            // 使用 MAC 指令做 acc = acc + w * xin
            acc = mac32(acc, w, xin);
        }
        if (acc > best_score) {
            best_score = acc;
            best_k = k;
        }
        //debug use
        printf("class %d score = %d\n", k, acc);
        
    }

    return best_k;
}

int main(void) {
    printf("Tiny MNIST int inference\n");
    printf("Model: C=%d, D=%d, IMG_SIZE=%d\n",
           TINY_MNIST_C, TINY_MNIST_D, TINY_MNIST_IMG_SIZE);

    int digit = tiny_mnist_predict(tiny_input_image);

    printf("Result is %d\n", digit);
    return 0;
}
