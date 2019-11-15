#include <stdio.h>
#include <evrpc.h>
#include <stdlib.h>
#include <string.h>

void memdump(const unsigned char *string, int zeilen);

void print_line(uintptr_t pos);

int memreplace(char *copy, char cin, char cout, uintptr_t *pInt);

int main(int argc, char **argv) {
    if (argc != 5) {
        printf("Incorrect usage!");
        return -1;
    }
    char *input = argv[1];
    int zeilen = atoi(argv[2]);
    char cin = *argv[3];
    char cout = *argv[4];
    uintptr_t last_replace_pos;

    char *copy = malloc(1024);

    memdump(input, zeilen);

    strcpy(copy, input);

    int replacements = memreplace(copy, cin, cout, &last_replace_pos);

    printf("\nLaenge der Zeichenkette (inkl. \\0): %lu Byte(s)\n"
           "Ersetzen: ’%c’ mit ’%c’\n"
           "Suchzeichen wurde %d mal gefunden und ersetzt\n"
           "zuletzt an Addr. 0x%lX\n\n",
           strlen(input) + 1,
           cin,
           cout,
           replacements,
           last_replace_pos);

    memdump(copy, zeilen);

    free(copy);
    return 0;
}

int memreplace(char *string, char cin, char cout, uintptr_t *last_replace_pos) {
    int replacements = 0;
    char* pos = string;
    while (*pos != 0) {
        if (*pos == cin) {
            *pos = cout;
            *last_replace_pos = (uintptr_t) pos;
            replacements++;
        }
        pos++;
    }
    return replacements;
}

void memdump(const unsigned char *string, int zeilen) {
    uintptr_t pos = (uintptr_t) string;

    pos = pos & -16;
    printf("%c[4m", 27);
    // header
    printf("   Pointer        ");
    for (int i = 0; i < 16; ++i) {
        printf("%02X ", i);
    }
    printf("         ASCII      \n");
    printf("%c[0m", 27);

    // body
    for (int i = 0; i < zeilen; ++i) {
        printf("0x%lX    ", pos);
        print_line(pos);
        pos += 16;
    }
}

void print_line(uintptr_t pos) {
    for (int i = 0; i < 16; ++i) {
        unsigned char value = *((unsigned char *) pos + i);
        printf("%02X ", value);
    }

    printf("    ");

    for (int i = 0; i < 16; ++i) {
        char value = *((char *) pos + i);
//        if ((value > 'a' && value < 'z') || (value > 'A' && value < 'Z')) {
        if (value >= ' ' && value <= '~') {
            printf("%c", value);
        } else {
            printf(".");
        }
    }
    printf("\n");
}
