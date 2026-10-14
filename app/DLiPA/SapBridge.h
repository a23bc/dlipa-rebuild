//  SapBridge.h
//
//  Public surface of the Go SAP bridge. gomobile generates this when binding
//  sapbridge into SapBridge.framework; the declaration is duplicated here so
//  the app compiles against a documented contract.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SapbridgeSigner : NSObject

- (nullable NSData *)sign:(NSData *)body error:(NSError **)error;
- (nullable NSString *)signatureHeaderValue:(NSData *)body error:(NSError **)error;
- (NSData *)hardware;
- (void)close;

@end

@interface Sapbridge : NSObject

+ (nullable SapbridgeSigner *)newSigner:(NSString *)setupURL
                               certURL:(NSString *)certURL
                               version:(int64_t)version
                              hardware:(NSData *)hardware
                                 error:(NSError **)error;
+ (nullable NSData *)kbsync:(NSData *)hardware dsid:(int64_t)dsid error:(NSError **)error;
+ (nullable NSString *)serialNumber:(NSData *)hardware error:(NSError **)error;
+ (NSString *)guidFromHardware:(NSData *)hardware;
+ (int64_t)parseDSID:(NSString *)value error:(NSError **)error;
+ (void)setBundleDir:(NSString *)path;
+ (NSString *)bundleDirValue;

@end

NS_ASSUME_NONNULLEND
