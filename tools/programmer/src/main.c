
// Copyright © 2023, Julian Scheffers, see LICENSE for more information

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
    uint8_t xsum = 2;

    uint8_t const *tx_ptr = (uint8_t const *)header;
    fwrite(tx_ptr, 1, sizeof(phdr_t), fd);
    for (size_t i = 0; i < sizeof(phdr_t); i++) {
        xsum += tx_ptr[i];
    }

    tx_ptr = (uint8_t const *)data;
    fwrite(tx_ptr, 1, header->length, fd);
    for (size_t i = 0; i < header->length; i++) {
        xsum += tx_ptr[i];
    }

    fputc(xsum, fd);
    fflush(fd);
}

// Send a packet.
void send_packet(phdr_t const *header, void const *data) {
    send_packet1(uart, header, data);
}

// Handle a received byte.
void handle_rx(uint8_t rxd) {
    if (rx_type == RX_NONE) {
        xsum = rxd;
        if (rxd == 2) {
            rx_len  = 0;
            rx_type = RX_PHDR;
            rx_ptr  = (uint8_t *)&header;
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
    printf("Unsupported packet length");
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
                printf("Sent checksum error: %02x vs %02x\n", (data.p_ack.cause >> 8) & 255, data.p_ack.cause & 255);
            } else {
                return true;
            }
        }
        try++;
    }
}



// Upload an ELF file to the thing.
bool upload_elf(char const *filename, bool run) {
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

        // Request a write.
        phdr_t phdr = {
            .type   = P_WRITE,
            .length = sizeof(p_write_t),
        };
        p_write_t p_write = {
            .addr   = seg.vaddr_req,
            .length = seg.size,
        };
        if (!await_packet(&phdr, &p_write) || !expect_ack(A_ACK)) {
            printf("P_WRITE failed.\n");
            kbelf_inst_unload(inst);
            kbelf_file_close(file);
            return false;
        }

        // Send write data.
        phdr = (phdr_t){
            .type   = P_WDATA,
            .length = seg.size,
        };
        if (!await_packet(&phdr, (void const *)seg.laddr) || !expect_ack(A_ACK)) {
            printf("P_WDATA failed.\n");
            kbelf_inst_unload(inst);
            kbelf_file_close(file);
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
bool get_id() {
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
bool jump(char const *raw, bool is_call) {
    // Decode hexadecimal address.
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
    if (address > UINT32_MAX) {
        printf("Hexadecimal out of range: %s\n", raw);
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



void get_help(int argc, char **argv) {
    char const *id = argc ? *argv : "boaprog";
    printf("Usage:\n");
    printf("    %s <port> upload <program-file>\n", id);
    printf("    %s <port> run <program-file>\n", id);
    printf("    %s <port> id\n", id);
    printf("    %s <port> jump <address>\n", id);
    printf("    %s <port> call <address>\n", id);
    exit(1);
}

// Original fcntl flags.
int            orig_flags;
// Original termios config.
struct termios orig_term;

void atexit_func() {
    // Restore UART.
    fcntl(fileno(uart), F_SETFL, orig_flags);
    tcsetattr(fileno(uart), TCSANOW, &orig_term);
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

    // Set UART to nonblocking.
    orig_flags = fcntl(0, F_GETFL);
    fcntl(fileno(uart), F_SETFL, orig_flags | O_NONBLOCK);
    // Set TTY to character break.
    tcgetattr(fileno(uart), &orig_term);
    struct termios new_term  = orig_term;
    new_term.c_oflag         = 0;
    new_term.c_iflag         = 0;
    new_term.c_lflag        &= ~ICANON & ~ECHO & ~ECHOE;
    tcsetattr(fileno(uart), TCSANOW, &new_term);

    if (argc == 4 && !strcmp(argv[2], "upload")) {
        return !upload_elf(argv[3], false);
    } else if (argc == 4 && !strcmp(argv[2], "run")) {
        return !upload_elf(argv[3], true);
    } else if (argc == 3 && !strcmp(argv[2], "id")) {
        return !get_id();
    } else if (argc == 4 && !strcmp(argv[2], "jump")) {
        return !jump(argv[3], false);
    } else if (argc == 4 && !strcmp(argv[2], "call")) {
        return !jump(argv[3], true);
    } else {
        get_help(argc, argv);
    }
    return 0;
}
