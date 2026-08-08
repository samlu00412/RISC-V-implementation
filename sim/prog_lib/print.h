#ifndef PRINT_H
#define PRINT_H

#include <stdarg.h>
#include <stdint.h>

volatile unsigned int _uart_base = 0xFFFF0100;
static int printf(const char *fmt, ...);

/* Low-level putc to UART */
__attribute__((section(".text4")))
static inline void uart_putc(char c) {
    *(volatile uint8_t *)_uart_base = (uint8_t)c;
}

/* Print signed decimal int */
__attribute__((section(".text4")))
static void print_dec(int x) {
    uint32_t v;
    int negative = 0;

    if (x == 0) {
        uart_putc('0');
        return;
    }

    if (x < 0) {
        negative = 1;
        uart_putc('-');
        v = (uint32_t)(-(x + 1)) + 1u;
    } else {
        v = (uint32_t)x;
    }

    /* 10^9, 10^8, ..., 10^0 */
    static const uint32_t pow10[] = {
        1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
        10000u,      1000u,      100u,      10u,      1u
    };

    int started = 0;

    for (int i = 0; i < 10; ++i) {
        uint32_t d = pow10[i];
        uint32_t digit = 0;

        while (v >= d) {
            v -= d;
            digit++;
        }

        if (digit != 0 || started || (i == 9)) {
            uart_putc((char)('0' + digit));
            started = 1;
        }
    }
}

/* Print unsigned decimal */
__attribute__((section(".text4")))
static void print_udec(unsigned int v) {
    if (v == 0u) {
        uart_putc('0');
        return;
    }

    static const unsigned int pow10[] = {
        1000000000u, 100000000u, 10000000u, 1000000u, 100000u,
        10000u,      1000u,      100u,      10u,      1u
    };

    int started = 0;

    for (int i = 0; i < 10; ++i) {
        unsigned int d = pow10[i];
        unsigned int digit = 0;

        while (v >= d) {
            v -= d;
            digit++;
        }

        if (digit != 0u || started || i == 9) {
            uart_putc((char)('0' + (int)digit));
            started = 1;
        }
    }
}

/* Print 32-bit hex (8 digits, no 0x prefix) */
__attribute__((section(".text4")))
static void print_hex(unsigned int x) {
    const char *digits = "0123456789abcdef";
    for (int i = 7; i >= 0; --i) {
        unsigned int nib = (x >> (i * 4)) & 0xFu;
        uart_putc(digits[nib]);
    }
}

/* Print C string (no newline) */
__attribute__((section(".text4")))
static void print_str(const char *s) {
    while (*s) {
        uart_putc(*s++);
    }
}

/* Simple puts: print string and '\n' */
__attribute__((section(".text4")))
static int puts(const char *s) {
    print_str(s);
    uart_putc('\n');
    return 0;
}
/*helper*/
static void u64_hex(uint64_t v) {
    uint32_t hi = (uint32_t)(v >> 32);
    uint32_t lo = (uint32_t)(v & 0xFFFFFFFFu);

    printf("%x%x\n", hi, lo);
}

/* Print 32-bit IEEE754 float from its bit pattern */
__attribute__((section(".text4")))
static void print_float_bits(uint32_t bits) {
    uint32_t sign = bits >> 31;
    uint32_t exp  = (bits >> 23) & 0xFFu;
    uint32_t frac = bits & 0x7FFFFFu;
    /* sign */
    if (sign) {
        uart_putc('-');
    }

    /* zero */
    if (exp == 0 && frac == 0) {
        uart_putc('0');
        uart_putc('.');
        uart_putc('0');
        return;
    }

    /* inf / nan */
    if (exp == 0xFFu) {
        const char *s = (frac == 0) ? "inf" : "nan";
        while (*s) uart_putc(*s++);
        return;
    }

    /* mantissa / exponent
       normal:   value = (2^23 + frac) * 2^(exp - 150)
       subnormal:value = frac * 2^(-149)
    */
    uint64_t mant;
    int      e2;
    if (exp == 0) {
        mant = frac;
        e2   = -149;
    } else {
        mant = ((uint64_t)1 << 23) | frac;
        e2   = (int)exp - 150;
    }
    int32_t  int_part = 0;
    uint64_t rem      = 0;
    int      q        = 0;

    if (e2 >= 0) {
        if (e2 > 31) {
            print_hex((uint32_t)bits);
            return;
        }
        uint64_t val = mant << e2;

        if (val > 0x7FFFFFFFULL) {
            print_hex((uint32_t)bits);
            return;
        }
        int_part = (int32_t)val;
        rem = 0;
        q   = 0;
    } else {
        q = -e2;  /* value = mant / 2^q */

        if (q >= 32) {
            int_part = 0;
            rem = mant;
        } else {
            int_part = (int32_t)(mant >> q);
            rem = mant - ((uint64_t)int_part << q);
        }
    }
  
    print_dec(int_part);
    uart_putc('.');

    if (rem == 0 || q == 0) {
        uart_putc('0');
        return;
    }

    const int decimals = 6;
    for (int i = 0; i < decimals; ++i) {
        rem *= 10u;

        uint64_t digit;
        if (q >= 64) 
            digit = 0;
        else
            digit = rem >> q;

        if (digit > 9u) digit = 9u;

        uart_putc((char)('0' + (int)digit));

        if (q < 64) 
            rem -= digit << q;
    }
}

/* Minimal printf: supports %d, %u, %x, %c, %s, %f and %% */
__attribute__((section(".text4")))
static int printf(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);

    while (*fmt) {
        if (*fmt == '%') {
            fmt++;  // skip '%'
            switch (*fmt) {

            case 'd': {     // signed decimal
                int v = va_arg(ap, int);
                print_dec(v);
                break;
            }

            case 'u': {     // unsigned decimal
                unsigned int v = va_arg(ap, unsigned int);
                print_udec(v);
                break;
            }

            case 'x': {     // hex (8 digits)
                unsigned int v = va_arg(ap, unsigned int);
                print_hex(v);
                break;
            }

            case 'c': {     // char
                int c = va_arg(ap, int); // promoted from char
                uart_putc((char)c);
                break;
            }

            case 's': {     // string
                const char *s = va_arg(ap, const char *);
                if (s) {
                    print_str(s);
                } else {
                    print_str("(null)");
                }
                break;
            }

            case 'f': { 
                uint32_t bits = va_arg(ap, uint32_t);
                print_float_bits(bits);
                break;
            }

            case '%': {     // "%%" -> "%"
                uart_putc('%');
                break;
            }

            default:
                /* Unknown specifier, print literally */
                uart_putc('%');
                uart_putc(*fmt);
                break;
            }

        } else {
            uart_putc(*fmt);
        }
        if (*fmt != '\0') {
            fmt++;
        }
    }

    va_end(ap);
    return 0;
}

/* Turn FP to INT for print */
typedef union {
    float f;
    uint32_t u;
} __printf_float_bits_t;

#define PF(x) ((__printf_float_bits_t){ .f = (x) }.u)

#endif /* PRINT_H */
