/* ============================================================================
 * printf.c — Minimal printf / ee_printf implementation for bare-metal targets.
 *
 * Supports the subset used by CoreMark:
 *   %d %i %u %x %X %s %c %%
 *   Width and zero-pad: %08x, %5d, etc.
 *   No floating point (CoreMark compiles with HAS_FLOAT=0).
 *
 * Output is routed via _write() → tohost side-channel characters.
 * ============================================================================ */

#include <stdarg.h>
#include <stdint.h>


/* Forward to _write stub */
extern int _write(int, const char*, int);

static void putch(char c) { _write(1, &c, 1); }

static void put_str(const char* s)
{
    while (*s) putch(*s++);
}

static void put_uint(unsigned long val, int base, int uppercase,
                     int width, char pad)
{
    char buf[32];
    int  len = 0;
    const char* digits = uppercase ? "0123456789ABCDEF" : "0123456789abcdef";

    if (val == 0) { buf[len++] = '0'; }
    else {
        while (val) {
            buf[len++] = digits[val % base];
            val /= base;
        }
    }
    /* pad left */
    for (int i = len; i < width; i++) putch(pad);
    /* reverse */
    for (int i = len - 1; i >= 0; i--) putch(buf[i]);
}

static void put_int(long val, int width, char pad)
{
    if (val < 0) { putch('-'); val = -val; if (width) width--; }
    put_uint((unsigned long)val, 10, 0, width, pad);
}

int printf(const char* fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    int count = 0;

    for (const char* p = fmt; *p; p++) {
        if (*p != '%') { putch(*p); count++; continue; }
        p++;
        /* flags / width */
        char pad   = ' ';
        int  width = 0;
        if (*p == '0') { pad = '0'; p++; }
        while (*p >= '0' && *p <= '9') { width = width*10 + (*p - '0'); p++; }
        /* length modifier (ignore l / ll) */
        int is_long = 0;
        if (*p == 'l') { is_long = 1; p++; if (*p == 'l') { p++; } }

        switch (*p) {
        case 'd': case 'i': {
            long v = is_long ? va_arg(ap, long) : (long)va_arg(ap, int);
            put_int(v, width, pad); break;
        }
        case 'u': {
            unsigned long v = is_long ? va_arg(ap, unsigned long)
                                      : (unsigned long)va_arg(ap, unsigned int);
            put_uint(v, 10, 0, width, pad); break;
        }
        case 'x': {
            unsigned long v = is_long ? va_arg(ap, unsigned long)
                                      : (unsigned long)va_arg(ap, unsigned int);
            put_uint(v, 16, 0, width, pad); break;
        }
        case 'X': {
            unsigned long v = is_long ? va_arg(ap, unsigned long)
                                      : (unsigned long)va_arg(ap, unsigned int);
            put_uint(v, 16, 1, width, pad); break;
        }
        case 's': {
            const char* s = va_arg(ap, const char*);
            put_str(s ? s : "(null)"); break;
        }
        case 'c': {
            char c = (char)va_arg(ap, int);
            putch(c); break;
        }
        case '%': putch('%'); break;
        default:  putch('%'); putch(*p); break;
        }
        count++;
    }
    va_end(ap);
    return count;
}

/* CoreMark calls ee_printf; map it to our printf */
int ee_printf(const char* fmt, ...)
{
    va_list ap;
    va_start(ap, fmt);
    /* re-use printf logic via vprintf-equivalent inline */
    char buf[512];
    int len = 0;
    /* simple: call printf with buf trick — just use printf directly */
    (void)buf; (void)len;
    va_end(ap);
    /* Delegate: reconstruct call */
    va_start(ap, fmt);
    /* Manual va-based output */
    for (const char* p = fmt; *p; p++) {
        if (*p != '%') { putch(*p); continue; }
        p++;
        char pad = ' '; int width = 0;
        if (*p == '0') { pad = '0'; p++; }
        while (*p >= '0' && *p <= '9') { width = width*10 + (*p-'0'); p++; }
        int il = 0;
        if (*p == 'l') { il = 1; p++; if (*p=='l') p++; }
        switch (*p) {
        case 'd': case 'i': {
            long v = il ? va_arg(ap,long) : (long)va_arg(ap,int);
            put_int(v, width, pad); break; }
        case 'u': {
            unsigned long v = il ? va_arg(ap,unsigned long)
                                 : (unsigned long)va_arg(ap,unsigned int);
            put_uint(v,10,0,width,pad); break; }
        case 'x': {
            unsigned long v = il ? va_arg(ap,unsigned long)
                                 : (unsigned long)va_arg(ap,unsigned int);
            put_uint(v,16,0,width,pad); break; }
        case 'X': {
            unsigned long v = il ? va_arg(ap,unsigned long)
                                 : (unsigned long)va_arg(ap,unsigned int);
            put_uint(v,16,1,width,pad); break; }
        case 's': { const char* s=va_arg(ap,const char*); put_str(s?s:""); break; }
        case 'c': { putch((char)va_arg(ap,int)); break; }
        case '%': putch('%'); break;
        default:  putch('%'); putch(*p); break;
        }
    }
    va_end(ap);
    return 0;
}
