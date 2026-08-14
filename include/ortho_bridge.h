#ifndef ORTHO_BRIDGE_H
#define ORTHO_BRIDGE_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

/// Structured error codes. Never panic across ABI.
typedef enum ortho_status {
    ORTHO_OK = 0,
    ORTHO_ERR_NULL_POINTER = 1,
    ORTHO_ERR_NOT_CONNECTED = 2,
    ORTHO_ERR_ALREADY_CONNECTED = 3,
    ORTHO_ERR_TIMEOUT = 4,
    ORTHO_ERR_INVALID_ARGUMENT = 5,
    ORTHO_ERR_DEVICE_NOT_FOUND = 6,
    ORTHO_ERR_QUEUE_FULL = 7,
    ORTHO_ERR_QUEUE_EMPTY = 8,
    ORTHO_ERR_TRANSPORT_FAILED = 9,
    ORTHO_ERR_IO = 10,
    ORTHO_ERR_FAULT = 11,
    ORTHO_ERR_UNKNOWN = 99
} ortho_status_t;

/// Opaque handles. Allocated on heap, freed via explicit free functions.
typedef struct ortho_device_t ortho_device_t;
typedef struct ortho_command_t ortho_command_t;
typedef struct ortho_buffer_t ortho_buffer_t;
typedef struct ortho_completion_t ortho_completion_t;
typedef struct ortho_memory_region_t ortho_memory_region_t;
typedef struct ortho_register_bank_t ortho_register_bank_t;
typedef struct ortho_trace_stream_t ortho_trace_stream_t;

/// Fabric command wire fields (matches fabric-command.schema.json)
typedef struct ortho_command_desc {
    const char* opcode;      // "execute" | "step" | "tensor" | "probe" | "reset" | "attest"
    const char* device;      // target device identifier
    uint64_t address;
    uint32_t length;
    uint64_t sequence;       // monotonic host sequence
    const char* payloadHash; // 64-char hex SHA-256
} ortho_command_desc_t;

/// Fabric completion wire fields (matches fabric-completion.schema.json)
/// cycles = ORTHO-32 architectural cycles (NOT ms, NOT ns)
/// Windows wall-clock timestamps are separate and never merged.
typedef struct ortho_completion_desc {
    uint64_t sequence;
    const char* status;      // "ok" | "error" | "timeout" | "fault"
    uint64_t cycles;         // architectural cycles
    const char* resultHash;  // 64-char hex
    const char* traceRoot;   // 64-char hex Merkle root
    int64_t hostSubmittedAtMs; // Windows wall-clock (ms since UNIX epoch)
    int64_t hostCompletedAtMs; // Windows wall-clock (ms since UNIX epoch)
} ortho_completion_desc_t;

// ---------------------------------------------------------------------------
// Device lifecycle
// ---------------------------------------------------------------------------

/// Create a device handle for the given transport kind.
/// transportKind: "pcie" | "usb" | "ethernet" | "fpga" | "simulated"
/// Returns NULL on allocation failure. Check status out-param.
/// Caller must call ortho_device_free().
ortho_device_t* ortho_device_create(const char* deviceId, const char* transportKind, ortho_status_t* outStatus);

/// Open connection to fabric. Validates non-null device.
/// Returns ORTHO_ERR_NULL_POINTER if device is NULL.
ortho_status_t ortho_device_open(ortho_device_t* device);

/// Close connection. Safe to call with NULL (no-op, returns NULL_POINTER code).
ortho_status_t ortho_device_close(ortho_device_t* device);

/// Free device handle. Safe to call with NULL (no-op).
void ortho_device_free(ortho_device_t* device);

/// Get device status string. Returns NULL if device is NULL.
const char* ortho_device_status(ortho_device_t* device);

// ---------------------------------------------------------------------------
// Command
// ---------------------------------------------------------------------------

/// Create command handle. Validates non-null pointers.
/// Caller must call ortho_command_free().
ortho_command_t* ortho_command_create(const ortho_command_desc_t* desc, ortho_status_t* outStatus);
void ortho_command_free(ortho_command_t* cmd);
ortho_status_t ortho_command_get_desc(const ortho_command_t* cmd, ortho_command_desc_t* outDesc);

// ---------------------------------------------------------------------------
// Buffer (DMA-capable host buffer)
// ---------------------------------------------------------------------------

ortho_buffer_t* ortho_buffer_alloc(uint64_t size, uint64_t alignment, ortho_status_t* outStatus);
void ortho_buffer_free(ortho_buffer_t* buf);
ortho_status_t ortho_buffer_map(ortho_buffer_t* buf);
ortho_status_t ortho_buffer_unmap(ortho_buffer_t* buf);
uint64_t ortho_buffer_size(const ortho_buffer_t* buf);
void* ortho_buffer_ptr(ortho_buffer_t* buf); // NULL if freed or NULL input

// ---------------------------------------------------------------------------
// Memory region
// ---------------------------------------------------------------------------

ortho_memory_region_t* ortho_memory_region_create(ortho_device_t* device, uint64_t baseAddress, uint64_t size, ortho_status_t* outStatus);
void ortho_memory_region_free(ortho_memory_region_t* region);
ortho_status_t ortho_memory_read_word(ortho_memory_region_t* region, uint64_t address, uint32_t* outValue);
ortho_status_t ortho_memory_write_word(ortho_memory_region_t* region, uint64_t address, uint32_t value);

// ---------------------------------------------------------------------------
// Register bank R0..R31 (R0 hardwired zero)
// ---------------------------------------------------------------------------

ortho_register_bank_t* ortho_register_bank_create(ortho_device_t* device, ortho_status_t* outStatus);
void ortho_register_bank_free(ortho_register_bank_t* bank);
ortho_status_t ortho_register_read(ortho_register_bank_t* bank, uint32_t index, uint32_t* outValue);
ortho_status_t ortho_register_write(ortho_register_bank_t* bank, uint32_t index, uint32_t value);

// ---------------------------------------------------------------------------
// Completion
// ---------------------------------------------------------------------------

ortho_completion_t* ortho_completion_create(const ortho_completion_desc_t* desc, ortho_status_t* outStatus);
void ortho_completion_free(ortho_completion_t* c);
ortho_status_t ortho_completion_get_desc(const ortho_completion_t* c, ortho_completion_desc_t* outDesc);

// ---------------------------------------------------------------------------
// Submit / Poll
// ---------------------------------------------------------------------------

/// Submit HOST COMMAND -> wait -> receive FABRIC COMPLETION.
/// Validates null pointers. Returns error code, never panics.
ortho_status_t ortho_device_submit(ortho_device_t* device, const ortho_command_t* cmd, ortho_completion_t** outCompletion);

/// Poll completion queue (non-blocking). Returns QUEUE_EMPTY if none.
ortho_status_t ortho_device_poll_completion(ortho_device_t* device, ortho_completion_t** outCompletion);

// ---------------------------------------------------------------------------
// DMA + Reset + Discovery
// ---------------------------------------------------------------------------

ortho_status_t ortho_dma_copy_to(ortho_device_t* device, uint64_t address, const ortho_buffer_t* buf);
ortho_status_t ortho_dma_copy_from(ortho_device_t* device, uint64_t address, ortho_buffer_t* buf, uint64_t length);
ortho_status_t ortho_device_reset(ortho_device_t* device, int mode); // 0=soft 1=hard 2=fabricOnly

// Discovery: enumerate available ORTHO-32 devices on host.
// Caller provides array of char* buffers; function fills count.
ortho_status_t ortho_discover_devices(char deviceIds[][64], size_t capacity, size_t* outCount);

// ---------------------------------------------------------------------------
// Trace
// ---------------------------------------------------------------------------

ortho_trace_stream_t* ortho_trace_decode(const uint8_t* data, size_t len, uint64_t sequence, ortho_status_t* outStatus);
void ortho_trace_free(ortho_trace_stream_t* trace);
size_t ortho_trace_cycle_count(const ortho_trace_stream_t* trace);

#ifdef __cplusplus
}
#endif

#endif // ORTHO_BRIDGE_H
