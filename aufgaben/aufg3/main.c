#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void memdump(char *string, int zeilen);

void print_line(char *pos);

int memreplace(char *copy, char cin, char cout, char **pInt);

int main(int argc, char **argv) {
    if (argc != 5) {
        printf("Incorrect usage!");
        return -1;
    }
    char *input = argv[1];
    int zeilen = atoi(argv[2]);
    char cin = *argv[3];
    char cout = *argv[4];
    char *last_replace_pos = NULL;

    char *copy = malloc(strlen(input)+1);

    memdump(input, zeilen);

    strcpy(copy, input);

    int replacements = memreplace(copy, cin, cout, &last_replace_pos);

    printf("\nLaenge der Zeichenkette (inkl. \\0): %lu Byte(s)\n"
           "Ersetzen: ’%c’ mit ’%c’\n"
           "Suchzeichen wurde %d mal gefunden und ersetzt\n"
           "zuletzt an Addr. %p\n\n",
           strlen(input) + 1,
           cin,
           cout,
           replacements,
           last_replace_pos);

    memdump(copy, zeilen);

    free(copy);
    return 0;
}

int memreplace(char *string, char cin, char cout, char **last_replace_pos) {
    int replacements = 0;
    char *pos = string;
    while (*pos != 0) {
        if (*pos == cin) {
            *pos = cout;
            *last_replace_pos = pos;
            replacements++;
        }
        pos++;
    }
    return replacements;
}

void memdump(char *string, int zeilen) {
    char *pos = string;

    long x = pos;
    pos = (char*)(x & ~0xf);

    printf("%c[4m", 27);
    // header
    printf("   Pointer        ");
    for (int i = 0; i < 16; ++i) {
        printf("%02X ", i);
    }
    printf("    0123456789abcdef\n");
    printf("%c[0m", 27);

    // body
    for (int i = 0; i < zeilen; ++i) {
        printf("0x%012lX    ", pos);
        print_line(pos);
        pos += 16;
    }
}

void print_line(char *pos) {
    for (int i = 0; i < 16; ++i) {
        printf("%02X ", pos[i]);
    }

    printf("    ");

    for (int i = 0; i < 16; ++i) {
        char value = pos[i]; 
//        if ((value > 'a' && value < 'z') || (value > 'A' && value < 'Z')) {
        if (value >= ' ' && value <= '~') {
            printf("%c", value);
        } else {
            printf(".");
        }
    }
    printf("\n");
}
