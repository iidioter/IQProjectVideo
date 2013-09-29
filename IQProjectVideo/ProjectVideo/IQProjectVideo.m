//
//  IQProjectVideo
//
//  Created by Iftekhar Mac Pro on 9/26/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.


#import "IQProjectVideo.h"
#import <AVFoundation/AVFoundation.h>

NSString *const IQFilePathKey = @"IQFilePath";
NSString *const IQFileSizeKey = @"IQFileSize";
NSString *const IQFileCreateDateKey = @"IQFileCreateDate";

@implementation IQProjectVideo
{
    NSMutableArray  *_images;
    NSTimer         *_stopTimer;
    CADisplayLink   *_displayLink;
}


- (id)init
{
    self = [super init];
    if (self) {
        _images = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void)cancel
{
    _path = nil;
    [_displayLink invalidate];
    [_stopTimer invalidate];
    [_images removeAllObjects];
}

-(void)startCapturingScreenshots
{
    //CADisplay link will call @selector(screenshot) at a refresh rate of screen display.
    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(screenshot)];
  
    /*When we scroll UIScrollView, UI updates, and _timer does not call 'screenshot' function. To fix this issue issue, we add our timer to our current runloop. Added by Iftekhar*/
    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

-(void)startVideoCaptureOfDuration:(NSInteger)seconds savePath:(NSString*)path
{
    [self cancel];
    
    _path = path;
    
    [self startCapturingScreenshots];
    
    _stopTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(stopVideoCapture) userInfo:nil repeats:NO];
}

-(void)startVideoCaptureWithSavePath:(NSString*)path
{
    [self cancel];
    
    [self startCapturingScreenshots];
    
    _path = path;
}

-(void)stopVideoCaptureWithProgress:(ProgressBlock)progressBlock completionHandler:(CompletionBlock)completionBlock
{
    _progressBlock = progressBlock;
    _completionBlock = completionBlock;
    
    //To free thread being hand.
    [self performSelector:@selector(stopVideoCapture) withObject:nil afterDelay:0.0001];
}

-(void)stopVideoCapture
{
    [_displayLink invalidate];
    [_stopTimer invalidate];
    
    UIWindow*   _window = [[UIApplication sharedApplication] keyWindow];
    
    [self writeImageAsMovie:_images toPath:_path size:_window.bounds.size];
}

//Private API. Can't be used for App Store app.
CGImageRef UIGetScreenImage(void);
int a = 0;

-(void)screenshot
{
    CGImageRef screen = UIGetScreenImage();
 
    UIImage *image = [[UIImage alloc] initWithCGImage:screen];
    
    if (image)  [_images addObject:[[UIImage alloc] initWithCGImage:screen]];
    
    CGImageRelease(screen);
}

-(void)writeImageAsMovie:(NSArray *)array toPath:(NSString*)path size:(CGSize)size
{
    @autoreleasepool {
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            NSError *error = nil;
            
            if ([[NSFileManager defaultManager] fileExistsAtPath:path])
                [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            
            AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                                   fileType:AVFileTypeMPEG4
                                                                      error:&error];
            NSParameterAssert(videoWriter);
            
            NSDictionary *videoSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                           AVVideoCodecH264, AVVideoCodecKey,
                                           [NSNumber numberWithInt:size.width], AVVideoWidthKey,
                                           [NSNumber numberWithInt:size.height], AVVideoHeightKey,
                                           nil];
            AVAssetWriterInput* writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
            
            AVAssetWriterInputPixelBufferAdaptor *adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput
                                                                                                                             sourcePixelBufferAttributes:nil];
            NSParameterAssert(writerInput);
            NSParameterAssert([videoWriter canAddInput:writerInput]);
            [videoWriter addInput:writerInput];
            
            //Start a session:
            [videoWriter startWriting];
            [videoWriter startSessionAtSourceTime:kCMTimeZero];
            
            int i = 0;
            
            CVPixelBufferRef buffer = NULL;
            buffer = [IQProjectVideo pixelBufferFromCGImage:[[array objectAtIndex:i] CGImage]];
            CVPixelBufferPoolCreatePixelBuffer (NULL, adaptor.pixelBufferPool, &buffer);
            
            [adaptor appendPixelBuffer:buffer withPresentationTime:kCMTimeZero];
            CVPixelBufferRelease(buffer);
            i++;
            
            if (_progressBlock != NULL)
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    _progressBlock((CGFloat)i/(CGFloat)array.count);
                });
            }
            
            NSLog(@"Ltimestamp:%f",_displayLink.timestamp);
            NSLog(@"Lduration:%f",_displayLink.duration);
            NSLog(@"LframeInterval:%d",_displayLink.frameInterval);
            

            
            while (1)
            {
                if (writerInput.readyForMoreMediaData == NO)
                {
                    //                NSLog(@"Not Ready");
                    sleep(0.001);
                    continue;
                }
                else
                {
                    CMTime frameTime = CMTimeMake(1, (int)(0.1/_displayLink.duration));
                    CMTime lastTime=CMTimeMake(i, (int)(1/_displayLink.duration));
                    CMTime presentTime=CMTimeAdd(lastTime, frameTime);
                    
                    if (i >= [array count])     buffer = NULL;
                    else                        buffer = [IQProjectVideo pixelBufferFromCGImage:[[array objectAtIndex:i] CGImage]];
                    
                    if (buffer)
                    {
                        // append buffer
                        [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                        CVPixelBufferRelease(buffer);
                        i++;
                        if (_progressBlock != NULL)
                        {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                _progressBlock((CGFloat)i/(CGFloat)array.count);
                            });
                        }
                    }
                    else
                    {
                        if (_progressBlock != NULL)
                        {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                _progressBlock((CGFloat)i/(CGFloat)array.count);
                            });
                        }
                        
                        NSLog (@"Finished AtPath:%@",path);
                        break;
                    }
                }
            }
            
            //Finish the session:
            [writerInput markAsFinished];
            
            if ([videoWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)])
            {
                [videoWriter finishWritingWithCompletionHandler:^{
                    CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
                }];
            }
            else
            {
                [videoWriter finishWriting];
                CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
            }
            [self cancel];
            
            
            NSDictionary *fileAttrubutes = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
            NSDictionary *dictInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                      path,IQFilePathKey,
                                      [fileAttrubutes objectForKey:NSFileSize], IQFileSizeKey,
                                      [fileAttrubutes objectForKey:NSFileCreationDate], IQFileCreateDateKey,
                                      nil];
            
            if (_completionBlock != NULL)
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    _completionBlock(dictInfo);
                });
            }
            
            NSString *openCommand = [NSString stringWithFormat:@"/usr/bin/open \"%@\"", NSTemporaryDirectory()];
            system([openCommand fileSystemRepresentation]);
        });
    }
}

//Helper functions
+ (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    NSDictionary *options = [[NSDictionary alloc] initWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];
    
    CVPixelBufferRef pxbuffer = NULL;
    CVPixelBufferCreate(kCFAllocatorDefault, CGImageGetWidth(image),
                        CGImageGetHeight(image), kCVPixelFormatType_32ARGB, (__bridge CFDictionaryRef) options,
                        &pxbuffer);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, CGImageGetWidth(image),
                                                 CGImageGetHeight(image), 8, 4*CGImageGetWidth(image), rgbColorSpace,
                                                 kCGImageAlphaNoneSkipFirst);
    
    CGContextConcatCTM(context, CGAffineTransformMakeRotation(0));
    
    //    CGAffineTransform flipVertical = CGAffineTransformMake( 1, 0, 0, -1, 0, CGImageGetHeight(image) );
    //    CGContextConcatCTM(context, flipVertical);
    
    //    CGAffineTransform flipHorizontal = CGAffineTransformMake( -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0 );
    //    CGContextConcatCTM(context, flipHorizontal);
    
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

@end
