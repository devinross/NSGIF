//
//  NSGIF.h
//
//  Created by Sebastian Dobrincu
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <AVFoundation/AVFoundation.h>

#if TARGET_OS_IPHONE
    #import <MobileCoreServices/MobileCoreServices.h>
    #import <UIKit/UIKit.h>
#elif TARGET_OS_MAC
    #import <CoreServices/CoreServices.h>
    #import <WebKit/WebKit.h>
#endif

@interface NSGIF : NSObject

+ (void) createGIFfromURL:(NSURL*)videoURL cropRect:(CGRect)crop outputSize:(CGSize)outputSize framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *gifURL))completionBlock;

+ (void) createGIFfromURL:(NSURL*)videoURL cropRect:(CGRect)crop framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *gifURL))completionBlock;

+ (void) createGIFfromURL:(NSURL*)videoURL framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *gifURL))completionBlock;

+ (void) createGIFfromURL:(NSURL*)videoURL scale:(CGFloat)scale framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *gifURL))completionBlock;

+ (void) createImagefromVideoURL:(NSURL*)videoURL completion:(void(^)(UIImage *image))completionBlock;

@end
