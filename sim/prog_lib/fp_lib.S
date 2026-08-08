.section .text1,"ax",@progbits
.text
.align  2

    # int fp_less(const float *x, const float *y);
    # return 1 if *x < *y, else 0
.global fp_less
fp_less:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # load *x, *y
    flw     ft0, 0(a0)        # ft0 = *x
    flw     ft1, 0(a1)        # ft1 = *y

    # ft2 = min(*x, *y)
    fmin.s  ft2, ft0, ft1

    # store raw bits to stack
    fsw     ft0, 0(sp)        # bits(x)
    fsw     ft1, 4(sp)        # bits(y)
    fsw     ft2, 8(sp)        # bits(min)

    lw      t0, 0(sp)         # t0 = bits(x)
    lw      t1, 4(sp)         # t1 = bits(y)
    lw      t2, 8(sp)         # t2 = bits(min)

    beq     t0, t1, 1f

    beq     t0, t2, 0f

    li      a0, 0
    j       2f

0:  li      a0, 1             # x < y
    j       2f

1:  li      a0, 0             # x == y

2:  lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
