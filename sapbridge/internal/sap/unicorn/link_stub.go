//go:build !(darwin || ios || linux) || !cgo

package unicorn

// ForceLink is a no-op where the cgo shim is not compiled. On those
// platforms Unicorn is either loaded from a shared library or unavailable,
// so there is no static archive to force into the link.
func ForceLink() {}
