# Boa bootloader protocol
This ROM implements a simple UART bootloader for easy program loading.
It can be used to:
- Read ROM
- Access RAM
- Call functions
- Jump to an entrypoint

This protocol is intended to be spoken by one controlling device the "programmer" and one subordinate device the "computer".
The programmer will send requests to the computer, and the computer may react to one request at a time.
The computer will only react when prompted by a message from the programmer.
If the computer does not react to a packet within 100ms, the packet is considered "missing" and is retransmitted.



# Packet format
The following is the basic layout of a packet:
| length | value    | description
| :----- | :------- | :----------
| 1      | 0x02     | Packet header
| 4      | type     | Describes the request or data stored in this packet
| 4      | length   | Length of the data field
| length | data     | Optional data field
| 1      | checksum | Additive checksum of all previous bytes


## List of packet types
| name      | value | description
| :-------- | :---- | :----------
| P_PING    | 0x00  | Ping packet, can be used to tell if the connection is alive
| P_PONG    | 0x01  | Ping response packet, echoes the data sent in the corresponding ping
| P_ACK     | 0x02  | Request acknowledgement
| P_WHO     | 0x03  | Identity request
| P_IDENT   | 0x04  | Identity response
| P_SPEED   | 0x05  | UART baudrate setting
| P_WRITE   | 0x10  | Prepare for a memory write
| P_READ    | 0x11  | Request a memory read
| P_WDATA   | 0x12  | Data associated with P_WRITE
| P_RDATA   | 0x13  | Data associated with P_READ
| P_JUMP    | 0x20  | Jump to a specified memory as 2nd stage boot
| P_CALL    | 0x21  | Call a specified address as a function


## Packet: P_PING
When a P_PING packet is received, the computer must send a P_PONG packet within 100ms, or the connection is presumed broken.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 16     | nonce    | Arbirary data


## Packet: P_PONG
The data in this packet must be equal to that of the P_PING packet, or the connection is presumed broken.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 16     | nonce    | The same data as the P_PING packet


## Packet: P_ACK
Acknowledgement of a previous packet, positive or negative, from either side of the connection.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 4      | status   | Acknowledgement status
| 4      | cause    | Error cause

### Acknowledgement status values
| name      | value | description
| :-------- | :---- | :----------
| A_ACK     | 0x00  | The operation was successful
| A_NACK    | 0x01  | The operation is possible, but not allowed
| A_XSUM    | 0x02  | Packet checksum mismatch
| A_NCAP    | 0x03  | The request is not supported
| A_ADDR    | 0x04  | The address range is not supported
| A_RDONLY  | 0x05  | The address range is read-only
| A_NOEXEC  | 0x06  | The address range is not executable
| A_TIME    | 0x07  | Communication timeout
| A_NSPEED  | 0x08  | Unsupported speed


## Packet: P_WHO
Identity request.


## Packet: P_IDENT
ASCII string representing the computer.
Format TBD.


## Packet: P_SPEED
Set the UART baud rate to a new value.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 4      | speed    | Desired baud rate


## Packet: P_WRITE
Request to write to physical memory.
The computer will send an acknowledgement in response, after which a P_WDATA packet may be sent.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 4      | addr     | Base address to write to
| 4      | length   | Length to write


## Packet: P_READ
Request to read from physical memory.
The computer will send a P_RDATA packet in response, or a P_ACK packet on error.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 4      | addr     | Base address to read from
| 4      | length   | Length to read


## Packet: P_WDATA
Data associated with P_WRITE, sent after P_ACK is received from the computer.


## Packet: P_RDATA
Data associated with P_READ, sent as acknowledgement after a P_READ is sent to the computer.


## Packet: P_JUMP
Request to jump to a physical address with interrupts and peripherals disabled.
Intended for booting programs over UART.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 4      | addr     | Address to jump to


## Packet: P_CALL
Request to call a function at a physical address.
Intended for debugging.

### Data field format
| length | value    | description
| :----- | :------- | :----------
| 4      | addr     | Address to call
