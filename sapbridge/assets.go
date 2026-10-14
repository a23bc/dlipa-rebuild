package sapbridge

import (
	"context"
	"time"

	"github.com/a23bc/dlipa-rebuild/sapbridge/internal/sap/assets"
)

// BundleDir is where the app looks for the four Apple binaries. The iOS app
// copies them out of its own bundle into Library/Caches on first launch,
// because assets.Load uses os.UserCacheDir().
var BundleDir string

// loadBundle resolves the pinned Apple SAP asset profile.
func loadBundle() assets.Bundle {
	dir := BundleDir
	if dir == "" {
		dir = bundleDir
	}
	if dir != "" {
		// The iOS app copies the four files here before first use.
		return assets.Bundle{
			AppleMediaServices: mustRead(dir + "/AppleMediaServices"),
			Commerce:           mustRead(dir + "/commerce"),
			CoreFP:             mustRead(dir + "/CoreFP"),
			CoreFPICXS:         mustRead(dir + "/CoreFP.icxs"),
		}
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	bundle, err := assets.Load(ctx)
	if err != nil {
		panic("sapbridge: Apple SAP assets unavailable: " + err.Error())
	}
	return bundle
}

func mustRead(path string) []byte {
	b, err := readFile(path)
	if err != nil {
		panic("sapbridge: cannot read " + path + ": " + err.Error())
	}
	return b
}
