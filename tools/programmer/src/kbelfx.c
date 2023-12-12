
#include <stdio.h>
#include <stdlib.h>

#include <kbelf.h>
#include <string.h>

// Memory allocator function to use for allocating metadata.
// User-defined.
void *kbelfx_malloc(size_t len) {
    return malloc(len);
}

// Memory allocator function to use for allocating metadata.
// User-defined.
void *kbelfx_realloc(void *mem, size_t len) {
    return realloc(mem, len);
}

// Memory allocator function to use for allocating metadata.
// User-defined.
void kbelfx_free(void *mem) {
    free(mem);
}


// Memory allocator function to use for loading program segments.
// Takes a segment with requested address and permissions and returns a segment with physical and virtual address
// information. If `paddr` is zero the allocation has failed. User-defined.
bool kbelfx_seg_alloc(kbelf_inst inst, size_t segs_len, kbelf_segment *segs) {
    if (!segs_len)
        return false;

    // Determine required size.
    kbelf_addr addr_min = -1;
    kbelf_addr addr_max = 0;
    for (size_t i = 0; i < segs_len; i++) {
        if (segs[i].vaddr_req < addr_min) {
            addr_min = segs[i].vaddr_req;
        }
        if (segs[i].vaddr_req + segs[i].size > addr_max) {
            addr_max = segs[i].vaddr_req + segs[i].size;
        }
    }

    // Allocate memory.
    void *mem = malloc(addr_max - addr_min);
    if (!mem)
        return false;

    // Compute segment addresses.
    for (size_t i = 0; i < segs_len; i++) {
        kbelf_laddr laddr    = (kbelf_laddr)mem + segs[i].vaddr_req - addr_min;
        segs[i].alloc_cookie = NULL;
        segs[i].laddr        = laddr;
        segs[i].vaddr_real   = segs[i].vaddr_req;
    }
    segs[0].alloc_cookie = mem;

    return true;
}

// Memory allocator function to use for loading program segments.
// Takes a previously allocated segment and unloads it.
// User-defined.
void kbelfx_seg_free(kbelf_inst inst, size_t segs_len, kbelf_segment *segs) {
    if (!segs_len)
        return;
    free(segs[0].alloc_cookie);
}


// Open a binary file for reading.
// User-defined.
void *kbelfx_open(char const *path) {
    FILE *fd = fopen(path, "rb");
    return fd;
}

// Close a file.
// User-defined.
void kbelfx_close(void *fd) {
    fclose((FILE *)fd);
}

// Reads a single byte from a file.
// Returns byte on success, -1 on error.
// User-defined.
int kbelfx_getc(void *fd) {
    return fgetc((FILE *)fd);
}

// Reads a number of bytes from a file.
// Returns the number of bytes read, or less than that on error.
// User-defined.
int kbelfx_read(void *fd, void *buf, int buf_len) {
    return fread(buf, 1, buf_len, (FILE *)fd);
}

// Sets the absolute offset in the file.
// Returns >=0 on success, -1 on error.
int kbelfx_seek(void *fd, long pos) {
    return fseek((FILE *)fd, pos, SEEK_SET);
}


// Find and open a dynamic library file.
// Returns non-null on success, NULL on error.
// User-defined.
kbelf_file kbelfx_find_lib(char const *needed) {
    return NULL;
}



// Measure the length of `str`.
size_t kbelfq_strlen(char const *str) {
    return strlen(str);
}
// Copy string from `src` to `dst`.
void kbelfq_strcpy(char *dst, char const *src) {
    strcpy(dst, src);
}
// Find last occurrance of `c` in `str`.
char const *kbelfq_strrchr(char const *str, char c) {
    return strrchr(str, c);
}
// Compare string `a` to `b`.
bool kbelfq_streq(char const *a, char const *b) {
    return !strcmp(a, b);
}

// Copy memory from `src` to `dst`.
void kbelfq_memcpy(void *dst, void const *src, size_t nmemb) {
    memmove(dst, src, nmemb);
}
// Fill memory `dst` with `c`.
void kbelfq_memset(void *dst, uint8_t c, size_t nmemb) {
    memset(dst, c, nmemb);
}
// Compare memory `a` to `b`.
bool kbelfq_memeq(void const *a, void const *b, size_t nmemb) {
    return !memcmp(a, b, nmemb);
}
