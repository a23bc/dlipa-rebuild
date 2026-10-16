//go:build darwin || ios || linux

package unicorn

/*

// Referencing Unicorn symbols from compiled code forces the linker to pull
// them out of libunicorn.a. Relying on -force_load alone is fragile: if that
// flag is dropped the archive is simply not linked, and purego.Dlsym then
// fails at runtime with an error that only shows up on a device.
//
// No #cgo LDFLAGS here on purpose. Go rejects -Wl,-export_dynamic inside the
// directive with "invalid flag in #cgo LDFLAGS", so the export flag is passed
// through the CGO_LDFLAGS environment variable instead, which the workflow sets
// for the gomobile bind step. This file only needs the undefined references.
extern unsigned int uc_version(unsigned int *major, unsigned int *minor);
extern int uc_open(int arch, int mode, void **uc);
extern int uc_close(void *uc);
extern int uc_mem_map(void *uc, unsigned long long address, unsigned long long size, unsigned int perms);
extern int uc_mem_write(void *uc, unsigned long long address, const void *bytes, unsigned long long size);
extern int uc_mem_read(void *uc, unsigned long long address, void *bytes, unsigned long long size);
extern int uc_mem_unmap(void *uc, unsigned long long address, unsigned long long size);
extern int uc_emu_start(void *uc, unsigned long long begin, unsigned long long until, unsigned long long timeout, unsigned long long count);
extern int uc_emu_stop(void *uc);
extern int uc_reg_read(void *uc, int regid, void *value);
extern int uc_reg_write(void *uc, int regid, const void *value);
extern int uc_hook_add(void *uc, void **hook, int type, void *callback, void *user_data, unsigned long long begin, unsigned long long end);
extern int uc_hook_del(void *uc, void *hook);
extern const char *uc_strerror(int code);
extern int uc_ctl(void *uc, unsigned int control, unsigned int arg);
extern int uc_query(void *uc, int query_type, unsigned long long *result);

// linkUnicorn is never called. It exists only to create the undefined
// references above so the linker resolves them from the static archive.
static void linkUnicorn(void) {
    unsigned int major = 0, minor = 0;
    void *uc = 0;
    void *hook = 0;
    uc_version(&major, &minor);
    uc_open(2, 0, &uc);
    uc_mem_map(uc, 0, 4096, 7);
    uc_mem_write(uc, 0, 0, 0);
    uc_mem_read(uc, 0, 0, 0);
    uc_mem_unmap(uc, 0, 4096);
    uc_reg_read(uc, 199, 0);
    uc_reg_write(uc, 199, 0);
    uc_hook_add(uc, &hook, 0, 0, 0, 0, 0);
    uc_hook_del(uc, hook);
    uc_emu_start(uc, 0, 0, 0, 0);
    uc_emu_stop(uc);
    uc_query(uc, 4, 0);
    uc_strerror(0);
    uc_ctl(uc, 0, 0);
    uc_close(uc);
}

void forceUnicornLink(void);
void forceUnicornLink(void) { linkUnicorn(); }
*/
import "C"

// ForceLink calls the C shim above. It is exported so the Go compiler must
// keep the translation unit that carries the undefined Unicorn references.
func ForceLink() {
	C.forceUnicornLink()
}
