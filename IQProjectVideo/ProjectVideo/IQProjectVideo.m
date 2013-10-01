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

static IQProjectVideo *shareObject;

@implementation IQProjectVideo
{
    NSOperationQueue    *_operationQueue;
    NSTimer             *_stopTimer;
    NSTimer             *_startTimer;
    NSMutableArray      *_dates;
    //    CADisplayLink     *_displayLink;
    
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* writerInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    CVPixelBufferRef buffer;
    NSUInteger currentIndex;
}


+(IQProjectVideo*)sharedController
{
    if (shareObject == nil)
    {
        shareObject = [[IQProjectVideo alloc] init];
    }
    
    return shareObject;
}


- (id)init
{
    self = [super init];
    if (self) {
        _operationQueue = [[NSOperationQueue alloc] init];
        [_operationQueue setMaxConcurrentOperationCount:1];
        _dates = [[NSMutableArray alloc] init];
        buffer = NULL;
        currentIndex = 0;
        _path = [NSTemporaryDirectory() stringByAppendingString:@"movie.mov"];
        
        [_operationQueue addOperationWithBlock:^{
            [self removeAllTemporaryFiles];
        }];
    }
    return self;
}

-(void)removeAllTemporaryFiles
{
    NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:NSTemporaryDirectory() error:nil];
    
    for (NSString *fileNames in items)
        [[NSFileManager defaultManager] removeItemAtPath:[NSHomeDirectory() stringByAppendingString:fileNames] error:nil];
}

-(void)cancel
{
    [_startTimer invalidate];
    //    [_displayLink invalidate];
    [_stopTimer invalidate];
    buffer = NULL;
    currentIndex = 0;
    _progressBlock = NULL;
    _completionBlock = NULL;
    
    [_dates removeAllObjects];
}

-(void)startCapturingScreenshots
{
    [_operationQueue addOperationWithBlock:^{
        if ([[NSFileManager defaultManager] fileExistsAtPath:_path])
            [[NSFileManager defaultManager] removeItemAtPath:_path error:nil];
        
        NSError *error = nil;
        videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:_path]
                                                fileType:AVFileTypeMPEG4
                                                   error:&error];
        
        UIWindow*   _window = [[UIApplication sharedApplication] keyWindow];
        NSDictionary *videoSettings = [[NSDictionary alloc] initWithObjectsAndKeys:
                                       AVVideoCodecH264, AVVideoCodecKey,
                                       [NSNumber numberWithInt:_window.bounds.size.width], AVVideoWidthKey,
                                       [NSNumber numberWithInt:_window.bounds.size.height], AVVideoHeightKey,
                                       nil];
        
        writerInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
        
        adaptor = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:writerInput sourcePixelBufferAttributes:nil];
        
        [videoWriter addInput:writerInput];
        
        //Start a session:
        [videoWriter startWriting];
        [videoWriter startSessionAtSourceTime:kCMTimeZero];
    }];
    
    _startTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(screenshot) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_startTimer forMode:NSRunLoopCommonModes];
    
    //    //CADisplay link will call @selector(screenshot) at a refresh rate of screen display.
    //    _displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(screenshot)];
    //
    //    /*When we scroll UIScrollView, UI updates, and _timer does not call 'screenshot' function. To fix this issue issue, we add our timer to our current runloop. Added by Iftekhar*/
    //    [_displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

-(void)startVideoCaptureOfDuration:(NSInteger)seconds WithProgress:(ProgressBlock)progressBlock completionBlock:(CompletionBlock)completionBlock
{
    [self cancel];
    _completionBlock = completionBlock;
    _progressBlock = progressBlock;
    
    [self startCapturingScreenshots];
    
    _stopTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(stopVideoCapture) userInfo:nil repeats:NO];
}

-(void)startVideoCapture
{
    [self cancel];
    
    [self startCapturingScreenshots];
}

-(void)stopVideoCaptureWithProgress:(ProgressBlock)progressBlock CompletionHandler:(CompletionBlock)completionBlock
{
    _completionBlock = completionBlock;
    _progressBlock = progressBlock;
    [self stopVideoCapture];
}

-(void)stopVideoCapture
{
    //    [_displayLink invalidate];
    [_startTimer invalidate];
    [_stopTimer invalidate];
    
    [self markFinishAndWriteMovie];
}

//Private API. Can't be used for App Store app.
CGImageRef UIGetScreenImage(void);

-(void)screenshot
{
    CGImageRef screen = UIGetScreenImage();
    [_dates addObject:[NSDate date]];
    
    [_operationQueue addOperationWithBlock:^{
        UIImage *image = [[UIImage alloc] initWithCGImage:screen];
        CGImageRelease(screen);
        if (image)
        {
            [UIImagePNGRepresentation(image) writeToFile:[NSTemporaryDirectory() stringByAppendingFormat:@"%d.png",currentIndex++] atomically:YES];
            //            NSLog(@"%d",currentIndex);
        }
    }];
}

-(void)markFinishAndWriteMovie
{
    [_operationQueue addOperationWithBlock:^{
        
        NSInteger i = 0;
        
        NSString *path = [NSTemporaryDirectory() stringByAppendingFormat:@"%d.png",i];
        UIImage *image;
        
        NSDate *startDate;
        
        while ((image = [UIImage imageWithContentsOfFile:path]))
        {
            while (1)
            {
                if (writerInput.readyForMoreMediaData == NO)
                {
                    sleep(0.01);
                    continue;
                }
                else
                {
                    //First time only
                    if (buffer == NULL)
                    {
                        CVPixelBufferPoolCreatePixelBuffer (NULL, adaptor.pixelBufferPool, &buffer);
                        startDate = [_dates objectAtIndex:i];
                    }
                    
                    buffer = [IQProjectVideo pixelBufferFromCGImage:image.CGImage];
                    
                    if (buffer)
                    {
                        NSDate *currentDate = [_dates objectAtIndex:i];
                        Float64 interval = [currentDate timeIntervalSinceDate:startDate];
                        
                        int32_t timeScale;
                        
                        if (i == 0)
                        {
                            timeScale = 1.0/([[_dates objectAtIndex:i+1] timeIntervalSinceDate:currentDate]);
                        }
                        else
                        {
                            timeScale = 1.0/([currentDate timeIntervalSinceDate:[_dates objectAtIndex:i-1]]);
                        }
                        
                        /**/
                        CMTime presentTime=CMTimeMakeWithSeconds(interval, MAX(33, timeScale));
                        //                        NSLog(@"presentTime:%@",(__bridge NSString *)CMTimeCopyDescription(kCFAllocatorDefault, presentTime));
                        
                        
                        if (_progressBlock != NULL)
                        {
                            dispatch_sync(dispatch_get_main_queue(), ^{
                                _progressBlock((CGFloat)i/(CGFloat)currentIndex);
                            });
                        }
                        
                        
                        // append buffer
                        [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                        CVPixelBufferRelease(buffer);
                    }
                    break;
                }
            }
            
            [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
            
            path = [NSTemporaryDirectory() stringByAppendingFormat:@"%d.png",++i];
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
        
        
        NSDictionary *fileAttrubutes = [[NSFileManager defaultManager] attributesOfItemAtPath:_path error:nil];
        NSDictionary *dictInfo = [NSDictionary dictionaryWithObjectsAndKeys:
                                  _path,IQFilePathKey,
                                  [fileAttrubutes objectForKey:NSFileSize], IQFileSizeKey,
                                  [fileAttrubutes objectForKey:NSFileCreationDate], IQFileCreateDateKey,
                                  nil];
        
        if (_completionBlock != NULL)
        {
            dispatch_sync(dispatch_get_main_queue(), ^{
                _completionBlock(dictInfo,videoWriter.error);
            });
        }
        
        NSString *openCommand = [NSString stringWithFormat:@"/usr/bin/open \"%@\"", NSTemporaryDirectory()];
        system([openCommand fileSystemRepresentation]);
    }];
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
