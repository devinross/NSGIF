//
//  NSGIF.m
//  
//  Created by Sebastian Dobrincu
//

#import "NSGIF.h"

@implementation NSGIF

// Declare constants
#define fileName     @"NSGIF"
#define timeInterval @(600)
#define tolerance    @(0.01)


#pragma mark - Public methods
// ALL TOGETHER
+ (void) createGIFfromURL:(NSURL*)videoURL
				 cropRect:(CGRect)crop
			   outputSize:(CGSize)outputSize
					scale:(CGFloat)scale
		  framesPerSecond:(NSInteger)fps
					 loop:(NSInteger)loop
				 progress:(void(^)(NSInteger currentFrame, NSInteger total))progressBlock
			   completion:(void(^)(NSURL *GifURL))completionBlock {
	
	// Convert the video at the given URL to a GIF, and return the GIF's URL if it was created.
	// The frames are spaced evenly over the video, and each has the same duration.
	// delayTime is the amount of time for each frame in the GIF.
	// loopCount is the number of times the GIF will repeat. Defaults to 0, which means repeat infinitely.
	AVURLAsset *asset = [AVURLAsset assetWithURL:videoURL];
	
	// Get the length of the video in seconds
	NSTimeInterval videoLength = asset.duration.value/asset.duration.timescale;
	NSInteger frames = fps * videoLength;
	NSTimeInterval delayTime = 1.0 / fps;
	NSTimeInterval increment = videoLength / frames; // How far along the video track we want to move, in seconds.

	NSDictionary *fileProp = [self filePropertiesWithLoopCount:loop]; 	// Create properties dictionaries
	NSDictionary *frameProp = [self framePropertiesWithDelayTime:delayTime];

	// Add frames to the buffer
	NSMutableArray *points = [NSMutableArray array];
	for (int currentFrame = 0; currentFrame<frames; ++currentFrame) {
		NSTimeInterval seconds = increment * currentFrame;
		CMTime time = CMTimeMakeWithSeconds(seconds, timeInterval.intValue);
		[points addObject:[NSValue valueWithCMTime:time]];
	}
	
	// Prepare group for firing completion block
	dispatch_group_t gifQueue = dispatch_group_create();
	dispatch_group_enter(gifQueue);
	
	__block NSURL *gifURL;
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		gifURL = [self dr_createGIFforTimePoints:points URL:videoURL fileProperties:fileProp frameProperties:frameProp frames:frames cropRect:crop scale:scale outputSize:outputSize progress:progressBlock];
		dispatch_group_leave(gifQueue);
	});
	
	dispatch_group_notify(gifQueue, dispatch_get_main_queue(), ^{
		completionBlock(gifURL);
	});
	
}

+ (void) createGIFfromURL:(NSURL*)videoURL cropRect:(CGRect)crop outputSize:(CGSize)outputSize framesPerSecond:(NSInteger)fps loop:(NSInteger)loop progress:(void(^)(NSInteger currentFrame, NSInteger total))progressBlock completion:(void(^)(NSURL *gifURL))completionBlock{
	[NSGIF createGIFfromURL:videoURL cropRect:crop outputSize:outputSize scale:1.0 framesPerSecond:fps loop:loop progress:progressBlock completion:completionBlock];
}

+ (void) createGIFfromURL:(NSURL*)videoURL cropRect:(CGRect)crop framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *GifURL))completionBlock {
	[NSGIF createGIFfromURL:videoURL cropRect:crop outputSize:CGSizeZero scale:1.0 framesPerSecond:fps loop:loop progress:nil completion:completionBlock];
}
+ (void) createGIFfromURL:(NSURL*)videoURL framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *GifURL))completionBlock {
	[NSGIF createGIFfromURL:videoURL cropRect:CGRectZero outputSize:CGSizeZero scale:1.0 framesPerSecond:fps loop:loop progress:nil completion:completionBlock];
}

+ (void) createGIFfromURL:(NSURL*)videoURL scale:(CGFloat)scale framesPerSecond:(NSInteger)fps loop:(NSInteger)loop completion:(void(^)(NSURL *gifURL))completionBlock {
	[NSGIF createGIFfromURL:videoURL cropRect:CGRectZero outputSize:CGSizeZero scale:scale framesPerSecond:fps loop:loop progress:nil completion:completionBlock];
}

+ (void) createImagefromVideoURL:(NSURL*)videoURL completion:(void(^)(UIImage *image))completionBlock {
	
	AVAsset *asset = [[AVURLAsset alloc] initWithURL:videoURL options:nil];

	AVAssetImageGenerator *ImgObj = [[AVAssetImageGenerator alloc] initWithAsset:asset];
	NSError *error = NULL;
	CMTime time = CMTimeMake(1, 65);
	CGImageRef refImg = [ImgObj copyCGImageAtTime:time actualTime:NULL error:&error];
	UIImage *finalImage= [[UIImage alloc] initWithCGImage:refImg];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		completionBlock(finalImage);
	});

	
}


+ (NSURL *) dr_createGIFforTimePoints:(NSArray *)timePoints URL:(NSURL *)url fileProperties:(NSDictionary *)fileProp frameProperties:(NSDictionary *)frameProp frames:(NSInteger)frameCount cropRect:(CGRect)cropRect scale:(CGFloat)scale outputSize:(CGSize)outputSize progress:(void(^)(NSInteger currentFrame, NSInteger total))progressBlock{
	
	NSString *timeEncodedFileName = [NSString stringWithFormat:@"%@-%@x%@-%lu.gif", fileName,@(outputSize.width),@(outputSize.height), (unsigned long)([[NSDate date] timeIntervalSince1970]*10.0)];
	NSString *temporaryFile = [NSTemporaryDirectory() stringByAppendingString:timeEncodedFileName];
	NSURL *fileURL = [NSURL fileURLWithPath:temporaryFile];
	if (fileURL == nil) return nil;
	
	CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, kUTTypeGIF , frameCount, NULL);
	CGImageDestinationSetProperties(destination, (CFDictionaryRef)fileProp);
	
	AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
	AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
	generator.appliesPreferredTrackTransform = YES;
	
	CMTime tol = CMTimeMakeWithSeconds([tolerance floatValue], [timeInterval intValue]);
	generator.requestedTimeToleranceBefore = tol;
	generator.requestedTimeToleranceAfter = tol;
	
	NSError *error = nil;
	CGImageRef previousImageRefCopy = nil;
	NSInteger i = 0;
	for (NSValue *time in timePoints) {
		@autoreleasepool {
			
			CGImageRef imageRef = [generator copyCGImageAtTime:time.CMTimeValue actualTime:nil error:&error];
			
			if(imageRef == nil) continue;
			
			if(!CGRectEqualToRect(CGRectZero, cropRect)){
				CGImageRef oldRef = imageRef;
				imageRef = CGImageCreateWithImageInRect(imageRef, cropRect);
				CFRelease(oldRef);
			}
			if(!CGSizeEqualToSize(CGSizeZero, outputSize)){
				imageRef = createImageAtSize(imageRef,outputSize);
			}else if(scale != 1.0){
				imageRef = createImageWithScale(imageRef, scale);
			}
			


			if (error) {
				NSLog(@"Error copying image: %@", error);
			}
//			if (imageRef) {
//				CGImageRelease(previousImageRefCopy);
//				previousImageRefCopy = CGImageCreateCopy(imageRef);
//			} else if (previousImageRefCopy) {
//				imageRef = CGImageCreateCopy(previousImageRefCopy);
//			} else {
//				NSLog(@"Error copying image and no previous frames to duplicate");
//				return nil;
//			}
			CGImageDestinationAddImage(destination, imageRef, (CFDictionaryRef)frameProp);
			CGImageRelease(imageRef);
	
			
		}
	
		
		if(progressBlock)
			progressBlock(i,timePoints.count);
		i++;
	}
	
	
	CGImageRelease(previousImageRefCopy);
	
	// Finalize the GIF
	if (!CGImageDestinationFinalize(destination)) {
		NSLog(@"Failed to finalize GIF destination: %@", error);
		if (destination != nil) {
			CFRelease(destination);
		}
		return nil;
	}
	CFRelease(destination);
	
	return fileURL;
}



#pragma mark - Helpers
CGImageRef createImageWithScale(CGImageRef imageRef, float scale) {
    
    #if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
    CGSize newSize = CGSizeMake(CGImageGetWidth(imageRef)*scale, CGImageGetHeight(imageRef)*scale);
    CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
    
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    if (!context) {
        return nil;
    }
    
    // Set the quality level to use when rescaling
    CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
    CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height);
    
    CGContextConcatCTM(context, flipVertical);
    // Draw into the context; this scales the image
    CGContextDrawImage(context, newRect, imageRef);
    
    //Release old image
    CFRelease(imageRef);
    // Get the resized image from the context and a UIImage
    imageRef = CGBitmapContextCreateImage(context);
    
    UIGraphicsEndImageContext();
    #endif
    
    return imageRef;
}
CGImageRef createImageAtSize(CGImageRef imageRef, CGSize newSize) {
	
#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
	CGRect newRect = CGRectIntegral(CGRectMake(0, 0, newSize.width, newSize.height));
	
	UIGraphicsBeginImageContextWithOptions(newSize, NO, 1);
	CGContextRef context = UIGraphicsGetCurrentContext();
	if (!context) {
		return nil;
	}
	
	// Set the quality level to use when rescaling
	CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
	CGAffineTransform flipVertical = CGAffineTransformMake(1, 0, 0, -1, 0, newSize.height);
	
	CGContextConcatCTM(context, flipVertical);
	// Draw into the context; this scales the image
	CGContextDrawImage(context, newRect, imageRef);
	
	//Release old image
	CFRelease(imageRef);
	// Get the resized image from the context and a UIImage
	imageRef = CGBitmapContextCreateImage(context);
	
	UIGraphicsEndImageContext();
#endif
	
	return imageRef;
}

#pragma mark - Properties
+ (NSDictionary*) filePropertiesWithLoopCount:(NSInteger)loopCount {
	NSDictionary *loop = @{
						   (NSString *)kCGImagePropertyGIFLoopCount: @(loopCount),
						   (NSString *)kCGImagePropertyGIFHasGlobalColorMap : @NO
						   
						   
						   };

    return @{(NSString *)kCGImagePropertyGIFDictionary : loop};
}
+ (NSDictionary*) framePropertiesWithDelayTime:(NSTimeInterval)delayTime {
	NSDictionary *delay = @{ (NSString *)kCGImagePropertyGIFDelayTime: @(delayTime) };
    return @{	(NSString *)kCGImagePropertyGIFDictionary	: delay,
                (NSString *)kCGImagePropertyColorModel		: (NSString *)kCGImagePropertyColorModelRGB
            };
}

@end
