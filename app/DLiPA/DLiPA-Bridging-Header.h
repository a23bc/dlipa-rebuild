//
// Exposes the gomobile-generated C API to Swift.
//
// The symbols live in the app binary itself, not in an embedded framework.
// gomobile produced them as a c-archive that the link force-loads, so the
// bundle is a single executable like the original DLiPA, with no
// Frameworks/ directory. That matters: a nested framework is one more thing
// MobileInstallation has to accept during registration.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SapbridgeSigner : NSObject
- (nullable NSData *)sign:(NSData *)body error:(NSError **)error;
- (NSString *)signatureHeaderValue:(NSData *)body error:(NSError **)error;
- (nullable NSData *)hardware;
- (BOOL)close:(NSError **)error;
@end

FOUNDATION_EXPORT NSString *SapbridgeBundleDirValue(void);
FOUNDATION_EXPORT NSString *SapbridgeGuidFromHardware(NSData *hardwareID);
FOUNDATION_EXPORT NSData *SapbridgeKBSync(NSData *hardwareID, NSString *dsid, NSError **error);
FOUNDATION_EXPORT SapbridgeSigner *SapbridgeNew(NSString *setupURL, NSString *certURL, int32_t version, NSData *hardwareID, NSError **error);
FOUNDATION_EXPORT BOOL SapbridgeParseDSID(NSString *value, int64_t *ret0_, NSError **error);
FOUNDATION_EXPORT NSString *SapbridgeSerialNumber(NSData *hardwareID, NSError **error);
FOUNDATION_EXPORT void SapbridgeSetBundleDir(NSString *path);

NS_ASSUME_NONNULL_END
