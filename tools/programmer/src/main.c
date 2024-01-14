
// Copyright © 2024, Julian Scheffers, see LICENSE for more information

#include "kbelf.h"
#include "protocol.h"

#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>

#include <fcntl.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>

// Maximum number of retries.
#define RETRY_COUNT 3

// Currently receiving nothing.
#define RX_NONE 0
// Currently receiving header.
#define RX_PHDR 1
// Currently receiving data.
#define RX_DATA 2
// Currently receiving checksum.
#define RX_XSUM 3
// Currently waiting; too much data.
#define RX_NCAP 5

// Number of columns in a hexdump.
#define HEXDUMP_COLS  16
// Number of bytes in a group.
#define HEXDUMP_GROUP 4
// Maximum block size of a write.
#define BLOCK_SIZE    1024

// Show raw transmissions in hexadecimal.
bool show_hex;

// Currently receiving.
int      rx_type;
// Receive count.
size_t   rx_len;
// Packet data pointer.
uint8_t *rx_ptr;
// Packet header buffer.
phdr_t   header;
// Packet data buffer.
p_data_t data;
// Current checksum.
uint8_t  xsum;
// Received checksum.
uint8_t  rx_xsum;

// UART handle.
FILE *uart;

// Handle a packet with incorrect checksum.
void handle_xsum();
// Handle an unsupported packet type.
void handle_ncap();
// Handle a successfully received packet.
void handle_packet();

// Send a packet to a different stream.
void send_packet1(FILE *fd, phdr_t const *header, void const *data) {
    fputc(2, fd);
    if (show_hex)
        printf("> 02");
    uint8_t xsum = 2;

    uint8_t const *tx_ptr = (uint8_t const *)header;
    fwrite(tx_ptr, 1, sizeof(phdr_t), fd);
    for (size_t i = 0; i < sizeof(phdr_t); i++) {
        if (show_hex)
            printf(" %02x", tx_ptr[i]);
        xsum += tx_ptr[i];
    }

    tx_ptr = (uint8_t const *)data;
    fwrite(tx_ptr, 1, header->length, fd);
    for (size_t i = 0; i < header->length; i++) {
        if (show_hex)
            printf(" %02x", tx_ptr[i]);
        xsum += tx_ptr[i];
    }

    if (show_hex)
        printf(" %02x\n", xsum);
    fputc(xsum, fd);
    fflush(fd);
}

// Send a packet.
void send_packet(phdr_t const *header, void const *data) {
    send_packet1(uart, header, data);
}

// Handle a received byte.
void handle_rx(uint8_t rxd) {
    if (rx_type == RX_NONE && show_hex) {
        printf("<");
    }
    if (show_hex) {
        printf(" %02x", rxd);
        fflush(stdout);
    }
    if (rx_type == RX_NONE) {
        xsum = rxd;
        if (rxd == 2) {
            rx_len  = 0;
            rx_type = RX_PHDR;
            rx_ptr  = (uint8_t *)&header;
        } else if (show_hex) {
            printf("\n");
        }
    } else if (rx_type == RX_PHDR) {
        rx_ptr[rx_len++] = rxd;
        if (rx_len == sizeof(phdr_t)) {
            rx_len = 0;
            if (header.length == 0) {
                rx_type = RX_XSUM;
            } else if (header.length > sizeof(data)) {
                rx_type = RX_NCAP;
            } else {
                rx_type = RX_DATA;
                rx_ptr  = (uint8_t *)&data;
            }
        }
        xsum += rxd;
    } else if (rx_type == RX_NCAP) {
        xsum += rxd;
        rx_len++;
        if (rx_len == header.length)
            rx_type = RX_XSUM;
    } else if (rx_type == RX_DATA) {
        rx_ptr[rx_len++]  = rxd;
        xsum             += rxd;
        if (rx_len == header.length)
            rx_type = RX_XSUM;
    } else if (rx_type == RX_XSUM) {
        rx_xsum = rxd;
        if (show_hex)
            printf("\n");
        if (xsum != rxd) {
            handle_xsum();
        } else if (header.length > sizeof(data)) {
            handle_ncap();
        } else {
            handle_packet();
        }
        rx_type = RX_NONE;
    }
}



static bool awaiting_packet, await_packet_resp;

// Handle a packet with incorrect checksum.
void handle_xsum() {
    printf("Received checksum error: %02x vs %02x\n", xsum, rx_xsum);
    awaiting_packet   = 0;
    await_packet_resp = false;
}

// Handle an unsupported packet type.
void handle_ncap() {
    printf("Unsupported packet length\n");
    awaiting_packet   = 0;
    await_packet_resp = false;
}

// Handle a successfully received packet.
void handle_packet() {
    awaiting_packet   = 0;
    await_packet_resp = true;
}

// Check if the received packet is a matching P_ACK packet.
bool expect_ack(uint8_t type) {
    return header.type == P_ACK && header.length == sizeof(p_ack_t) && data.p_ack.ack_type == type;
}

// Await a packet.
bool await_packet(phdr_t const *phdr, void const *pdat) {
    int try = 0;
    while (1) {
        if (try > RETRY_COUNT) {
            FILE *fd = fopen("/tmp/boaprog_msg", "wb");
            if (fd) {
                send_packet1(fd, phdr, pdat);
                fclose(fd);
            }
            return false;
        } else if (try) {
            printf("Retry %d/%d\n", try, RETRY_COUNT);
        }
        awaiting_packet = true;
        send_packet(phdr, pdat);
        while (awaiting_packet) {
            int c = fgetc(uart);
            if (c >= 0)
                handle_rx(c);
        }
        if (await_packet_resp) {
            if (expect_ack(A_XSUM)) {
                printf(
                    "Sent checksum error: sent %02x, got %02x\n",
                    (data.p_ack.cause >> 8) & 255,
                    data.p_ack.cause & 255
                );
            } else {
                return phdr->type != P_ACK || ((p_ack_t *)pdat)->ack_type == A_ACK;
            }
        }
        try++;
    }
}



// Try to decode a HEX string.
bool decode_hex(char const *raw, uint64_t *out) {
    if (raw[0] == '0' && (raw[1] | 0x20) == 'x') {
        raw += 2;
    }
    if (!*raw) {
        printf("Invalid hexadecimal: %s\n", raw);
        return false;
    }
    char const        *end     = raw;
    unsigned long long address = strtoull(raw, (char **)&end, 16);
    if (end < raw + strlen(raw)) {
        printf("Invalid hexadecimal: %s\n", raw);
        return false;
    }
    *out = address;
    return true;
}

// Try to decode a number.
bool decode_num(char const *raw, uint64_t *out) {
    if (raw[0] == '0' && (raw[1] | 0x20) == 'x') {
        return decode_hex(raw + 2, out);
    }
    char const        *end     = raw;
    unsigned long long address = strtoull(raw, (char **)&end, 10);
    if (end < raw + strlen(raw)) {
        printf("Invalid decimal: %s\n", raw);
        return false;
    }
    *out = address;
    return true;
}

// Ceil logarithm 2 of number.
unsigned int clog2(uintmax_t x) __attribute_const__;
unsigned int clog2(uintmax_t x) {
    unsigned int q = 0;
    while (((uintmax_t)1 << q) < x) q++;
    return q;
}



// Write a bunch of data to the computer without splitting it up.
bool write_mem_block(uint32_t addr, void const *wdata, size_t length) {
    // Set up a write command.
    phdr_t phdr = {
        .type   = P_WRITE,
        .length = sizeof(p_read_t),
    };
    p_read_t pdat = {
        .addr   = addr,
        .length = length,
    };
    if (!await_packet(&phdr, &pdat) || !expect_ack(A_ACK)) {
        printf("P_WRITE failed.\n");
        return false;
    }

    phdr = (phdr_t){
        .type   = P_WDATA,
        .length = length,
    };
    if (!await_packet(&phdr, wdata) || !expect_ack(A_ACK)) {
        printf("P_WDATA failed.\n");
        return false;
    }

    return true;
}

// Write a bunch of data to the computer.
bool write_mem(uint32_t addr, void const *_wdata, size_t length) {
    uint8_t const *wdata = _wdata;
    for (size_t i = 0; i < length; i += BLOCK_SIZE) {
        write_mem_block(addr + i, wdata + i, BLOCK_SIZE < length - i ? BLOCK_SIZE : length - i);
    }
    return true;
}

// Try to ping the computer.
bool ping() {
    phdr_t phdr = {
        .type   = P_PING,
        .length = sizeof(p_ping_t),
    };
    p_ping_t pdat;

    // Attempt to put random date in the ping.
    FILE *fd = fopen("/dev/random", "rb");
    if (fd)
        fread(&pdat, 1, sizeof(pdat), fd);
    else
        memset(&pdat, 0xcc, sizeof(pdat));

    // Send the ping packet.
    if (!await_packet(&phdr, &pdat)) {
        return false;
    }
    if (memcmp(&pdat, &data.p_ping, sizeof(pdat))) {
        printf("Ping payload mismatch.\n");
        return false;
    } else {
        return true;
    }
}

// Try to change the UART speed.
bool f_change_speed(int new_speed) {
    // Speed change packet.
    phdr_t phdr = {
        .type   = P_SPEED,
        .length = sizeof(p_speed_t),
    };
    p_speed_t pdat = {
        .speed = new_speed,
    };

    // Request speed change.
    if (!await_packet(&phdr, &pdat)) {
        return false;
    }
    if (expect_ack(A_NSPEED)) {
        printf("Speed %d unsupported\n", new_speed);
        return false;
    } else if (!expect_ack(A_ACK)) {
        printf("Speed change unsupported\n");
        return false;
    }

    // Upon ACK, change serial port speed.
    fflush(uart);
    struct termios new_term;
    tcgetattr(fileno(uart), &new_term);
    cfsetispeed(&new_term, new_speed);
    cfsetospeed(&new_term, new_speed);
    tcsetattr(fileno(uart), TCSANOW, &new_term);

    // Wait around for just a moment to let everyone catch up.
    usleep(10000);

    // If a ping succeeds the baudrate change was successful.
    if (ping()) {
        printf("Speed changed to %d\n", new_speed);
        return true;
    } else {
        return false;
    }
}



// Upload an ELF file to the thing.
bool f_upload_elf(char const *filename, bool run) {
    // Open ELF file.
    kbelf_file file = kbelf_file_open(filename, NULL);
    if (!file) {
        printf("Failed to open %s\n", filename);
        return false;
    }

    // Load ELF segments.
    kbelf_inst inst = kbelf_inst_load(file, 0);
    if (!inst) {
        printf("Failed to load %s\n", filename);
        kbelf_file_close(file);
        return false;
    }

    // Send write commands.
    for (size_t i = 0; i < kbelf_inst_segment_len(inst); i++) {
        kbelf_segment seg = kbelf_inst_segment_get(inst, i);
        printf("Writing to 0x%08x (%zu%%)\n", seg.vaddr_req, (i + 1) * 100 / kbelf_inst_segment_len(inst));

        // Write the memory.
        if (!write_mem(seg.vaddr_req, (void const *)seg.laddr, seg.size)) {
            return false;
        }
    }

    if (run) {
        // Run the ELF file.
        phdr_t phdr = {
            .type   = P_JUMP,
            .length = sizeof(p_jump_t),
        };
        p_jump_t p_jump = {
            .addr = kbelf_inst_entrypoint(inst),
        };
        if (!await_packet(&phdr, &p_jump) || !expect_ack(A_ACK)) {
            printf("P_JUMP failed.\n");
            kbelf_inst_unload(inst);
            kbelf_file_close(file);
            return false;
        }
    }

    // Clean up.
    kbelf_inst_unload(inst);
    kbelf_file_close(file);
    return true;
}

// Get and print an ID.
bool f_get_id() {
    phdr_t phdr = {
        .type   = P_WHO,
        .length = 0,
    };
    if (!await_packet(&phdr, NULL) || header.type != P_IDENT || header.length == 0) {
        return false;
    }
    printf("Identity:\n");
    fwrite(data.raw, 1, header.length, stdout);
    printf("\n");
}

// Give a jump or call command.
bool f_jump(char const *raw, bool is_call) {
    // Decode hexadecimal address.
    uint64_t address;
    if (!decode_hex(raw, &address))
        return false;
    if (address > UINT32_MAX) {
        printf("Address out of range: %s\n", raw);
        return false;
    }

    // Send jump or call request.
    phdr_t phdr = {
        .type   = is_call ? P_CALL : P_JUMP,
        .length = sizeof(p_jump_t),
    };
    p_jump_t p_jump = {
        .addr = address,
    };

    return await_packet(&phdr, &p_jump) && expect_ack(A_ACK);
}

// Read a range of memory.
bool f_read(char const *raw_addr, char const *raw_len, char const *raw_file) {
    // Decode hexadecimal address.
    uint64_t address, length;
    if (!decode_hex(raw_addr, &address))
        return false;
    if (address > UINT32_MAX) {
        printf("Address out of range: %s\n", raw_addr);
        return false;
    }
    if (!decode_num(raw_len, &length))
        return false;
    if (length > UINT32_MAX) {
        printf("Address out of range: %s\n", raw_len);
        return false;
    }

    // Set up a read command.
    phdr_t phdr = {
        .type   = P_READ,
        .length = sizeof(p_read_t),
    };
    p_read_t pdat = {
        .addr   = address,
        .length = length,
    };
    if (!await_packet(&phdr, &pdat) || header.type != P_RDATA) {
        return false;
    }

    if (raw_file) {
        // Dump data to file.
        FILE *fd = fopen(raw_file, "wb");
        if (!fd)
            return false;
        fwrite(&data.raw, 1, header.length, fd);
        fclose(fd);

    } else {
        // Dump data to STDOUT.
        for (size_t row = 0; row < (header.length - 1) / HEXDUMP_COLS + 1; row++) {
            printf("%0*zx:", (clog2(header.length) - 1) / 4 + 1, row * HEXDUMP_COLS);
            for (size_t col = 0; col < HEXDUMP_COLS; col++) {
                if (col % HEXDUMP_GROUP == 0) {
                    putchar(' ');
                }
                if (row * HEXDUMP_COLS + col < header.length) {
                    printf(" %02x", data.raw[row * HEXDUMP_COLS + col]);
                } else {
                    printf("   ");
                }
            }
            printf("  ");
            for (size_t col = 0; col < HEXDUMP_COLS; col++) {
                if (col % HEXDUMP_GROUP == 0) {
                    putchar(' ');
                }
                if (row * HEXDUMP_COLS + col < header.length) {
                    char c = (char)data.raw[row * HEXDUMP_COLS + col];
                    if (c < 0x20 || c >= 0x7f) {
                        putchar('.');
                    } else {
                        putchar(c);
                    }
                } else {
                    break;
                }
            }
            putchar('\n');
        }
    }
    return true;
}

// Write a range of memory.
bool f_write(char const *raw_addr, char const *raw_len, char const *raw_file) {
    // Decode hexadecimal address.
    uint64_t address, length;
    if (!decode_hex(raw_addr, &address))
        return false;
    if (address > UINT32_MAX) {
        printf("Address out of range: %s\n", raw_addr);
        return false;
    }
    if (!decode_num(raw_len, &length))
        return false;
    if (length > UINT32_MAX) {
        printf("Address out of range: %s\n", raw_len);
        return false;
    }

    // Prepare write data.
    void *wdata = malloc(length);
    if (!wdata) {
        printf("Out of memory (allocating %zu byte%c)\n", length, length ? 's' : 0);
        return false;
    }
    memset(wdata, 0, length);
    if (raw_file[0] >= '0' && raw_file[0] <= '9') {
        // Unsigned number.
        uint64_t tmp;
        if (!decode_num(raw_file, &tmp)) {
            return false;
        }
        memcpy(wdata, &tmp, sizeof(tmp));
    } else if (raw_file[0] == '-') {
        // Signed number.
        int64_t tmp;
        if (!decode_num(raw_file + 1, (uint64_t *)&tmp)) {
            return false;
        }
        tmp = -tmp;
        memcpy(wdata, &tmp, sizeof(tmp));
    } else {
        // Binary data.
        FILE *fd = fopen(raw_file, "rb");
        if (!fd) {
            printf("File not found.\n");
            return false;
        }
        fread(wdata, 1, length, fd);
        fclose(fd);
    }

    // Write the memory.
    if (!write_mem(address, wdata, length)) {
        free(wdata);
        return false;
    }

    free(wdata);
    return true;
}



void get_help(int argc, char **argv) {
    char const *id = argc ? *argv : "boaprog";
    printf("Usage:\n");
    printf("    %s <port> upload <program-file>\n", id);
    printf("    %s <port> run <program-file>\n", id);
    printf("    %s <port> id\n", id);
    printf("    %s <port> ping\n", id);
    printf("    %s <port> jump <address>\n", id);
    printf("    %s <port> call <address>\n", id);
    printf("    %s <port> read <address> <length> [outfile]\n", id);
    printf("    %s <port> write <address> <length> <infile|value>\n", id);
    exit(1);
}

// Original fcntl flags.
int            orig_flags;
// Original termios config.
struct termios orig_term;

void atexit_func() {
    // Restore UART.
    fcntl(fileno(uart), F_SETFL, orig_flags);
    // tcsetattr(fileno(uart), TCSANOW, &orig_term);
}

int main(int argc, char **argv) {
    if (argc < 3) {
        get_help(argc, argv);
    }

    // Add exit handlers.
    atexit(atexit_func);

    // Open UART.
    uart = fopen(argv[1], "w+b");
    if (!uart) {
        printf("Failed to open %s\n", argv[1]);
    }

    show_hex = getenv("SHOW_HEX");

    // Set UART to nonblocking.
    orig_flags = fcntl(0, F_GETFL);
    fcntl(fileno(uart), F_SETFL, orig_flags | O_NONBLOCK);
    // Set TTY to character break.
    tcgetattr(fileno(uart), &orig_term);
    struct termios new_term = orig_term;
    cfsetispeed(&new_term, 19200);
    cfsetospeed(&new_term, 19200);
    cfmakeraw(&new_term);
    tcsetattr(fileno(uart), TCSANOW, &new_term);

    // Configure speed.
    char *speed_str = getenv("BOAPROG_SPEED");
    if (speed_str) {
        int speed = atoi(speed_str);
        if (speed > 0) {
            f_change_speed(speed);
        } else {
            printf("Ignoring invalid speed %s\n", speed_str);
        }
    }

    if (argc == 4 && !strcmp(argv[2], "upload")) {
        return !f_upload_elf(argv[3], false);
    } else if (argc == 4 && !strcmp(argv[2], "run")) {
        return !f_upload_elf(argv[3], true);
    } else if (argc == 3 && !strcmp(argv[2], "ping")) {
        return !ping();
    } else if (argc == 3 && !strcmp(argv[2], "id")) {
        return !f_get_id();
    } else if (argc == 4 && !strcmp(argv[2], "jump")) {
        return !f_jump(argv[3], false);
    } else if (argc == 4 && !strcmp(argv[2], "call")) {
        return !f_jump(argv[3], true);
    } else if (argc | 1 == 6 && !strcmp(argv[2], "read")) {
        return !f_read(argv[3], argv[4], argc == 6 ? argv[5] : NULL);
    } else if (argc == 6 && !strcmp(argv[2], "write")) {
        return !f_write(argv[3], argv[4], argv[5]);
    } else {
        get_help(argc, argv);
    }
    return 0;
}
