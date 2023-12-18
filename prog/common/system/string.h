
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

#pragma once

#include <stddef.h>

#ifndef __restrict
#ifdef __cplusplus
#define __restrict
#else
#define __restrict restrict
#endif
#endif

#ifndef __pure
#define __pure __attribute__((pure))
#endif

#ifdef __cplusplus
extern "C" {
#endif

/* ==== RAW MEMORY FUNCTIONS ==== */

// Finds the first occurrance of `__c` in `__mem`, searching `__len` bytes.
// Returns a pointer to the first occurrance, or NULL if not found.
void *memchr(void const *__mem, int __c, size_t __len) __pure;
// Finds the last occurrance of `__c` in `__mem`, searching `__len` bytes.
// Returns a pointer to the last occurrance, or NULL if not found.
void *memrchr(void const *__mem, int __c, size_t __len) __pure;
// Compare byte arrays `__a` and `__b`, searching `__len` bytes.
// Returns difference <0 or >0 for first different byte, or 0 if `__a` and `__b` are equal.
int   memcmp(void const *__a, void const *__b, size_t __len) __pure;
// Copies data from `__src` to `__dst`, copying at most `__len` bytes, stopping when a byte equal to `__c` has been
// copied. Does not gaurantee correct behaviour for overlapping `__src` and `__dst`. Returns a pointer to `__dst` pas
// the end of the copied `__c` or NULL if `__c` was not found.
void *memccpy(void *__restrict __dst, void const *__restrict __src, int __c, size_t __len) __pure;
// Copies data from `__src` to `__dst`, copying `__len` bytes.
// Does not gaurantee correct behaviour for overlapping `__src` and `__dst`.
// Returns a pointer to `__dst`.
void *memcpy(void *__restrict __dst, void const *__restrict __src, size_t __len) __pure;
// Copies data from `__src` to `__dst`, copying `__len` bytes.
// Gaurantees correct copying behaviour for overlapping `__src` and `__dst`.
// Returns a pointer to `__dst`.
void *memmove(void *__dst, void const *__src, size_t __len) __pure;
// Sets `__len` bytes of `__dst` to `__c`.
// Returns a pointer to `__dst`.
void *memset(void *__dst, int __c, size_t __len) __pure;



/* ==== STRING FUNCTIONS ==== */

// Find the first occurrance of `__c` in the c-string `__mem`.
// Returns a pointer to the first occurrance, or NULL if not found.
char  *strchr(char const *__mem, int __c) __pure;
// Find the last occurrance of `__c` in the c-string `__mem`.
// Returns a pointer to the last occurrance, or NULL if not found.
char  *strrchr(char const *__mem, int __c) __pure;
// Compare c-strings `__a` and `__b`.
// Returns difference <0 or >0 for first different byte, or 0 if `__a` and `__b` are equal.
int    strcmp(char const *__a, char const *__b) __pure;
// Compare c-strings `__a` and `__b`, searching at most `__len` bytes.
// Returns difference <0 or >0 for first different byte, or 0 if `__a` and `__b` are equal.
int    strncmp(char const *__a, char const *__b, size_t __len) __pure;
// Concatenate the c-string `__src` onto the c-string `__dst`.
// Returns a pointer to `__dst`.
char  *strcat(char *__dst, char const *__src) __pure;
// Concatenate at most `__len` bytes of the c-string `__src` onto the c-string `__dst`.
// This means that if `__len <= strlen (__src)`, `__dst` will have no NULL terminator.
// Returns a pointer to `__dst`.
char  *strncat(char *__dst, char const *__src, size_t __len) __pure;
// Copy the c-string `__src` over the c-string `__dst`.
// Returns a pointer to `__dst`.
char  *strcpy(char *__dst, char const *__src) __pure;
// Copy the c-string `__src` over the c-string `__dst` such that exactly `__len` bytes are written.
// This means that if `__len <= strlen (__src)`, `__dst` will have no NULL terminator.
// Returns a pointer to `__dst`.
char  *strncpy(char *__dst, char const *__src, size_t __len) __pure;
// Determines the number of initial bytes of the c-string `__mem` that consist only of bytes in the c-string `__accept`.
size_t strspn(char const *__mem, char const *__accept) __pure;
// Determines the number of initial bytes of the c-string `__mem` that consist only of bytes not in the c-string
// `__reject`.
size_t strcspn(char const *__mem, char const *__reject) __pure;
// Finds the first occurrance of the c-string `__substr` in the c-string `__mem`.
// Returns a pointer to the substring if found, NULL if not found.
char  *strstr(char const *__mem, char const *__substr) __pure;
// Finds the first occurrance of the c-string `__substr` (case-insensitive) in the c-string `__mem`.
// Returns a pointer to the substring if found, NULL if not found.
char  *strcasestr(char const *__mem, char const *__substr) __pure;
// Determines the length of the c-string `__mem`.
// Returns the index of the byte 0 in the c-string `__mem`.
size_t strlen(char const *__mem) __pure;
// Determines the length of the c-string `__mem`, searching `__len` bytes.
// Returns the index of the byte 0 in the c-string `__mem`, or `__len` if there was no 0 byte.
size_t strnlen(char const *__mem, size_t __len) __pure;
// Allocates memory and duplicates the c-string `__mem`.
char  *strdup(char const *__mem) __pure;
// Allocates memory and duplicates the c-string `__mem`.
// Copies at most `__len` characters from the input before adding a NULL terminator.
char  *strndup(char const *__mem, size_t __len) __pure;

#ifdef __cplusplus
} // extern "C"
#endif