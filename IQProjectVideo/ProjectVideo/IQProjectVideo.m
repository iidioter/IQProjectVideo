//
//  IQProjectVideo
//
//  Created by Iftekhar Mac Pro on 9/26/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.


#import "IQProjectVideo.h"
#import <AVFoundation/AVFoundation.h>

NSString *const IQFilePathKey       = @"IQFilePath";
NSString *const IQFileSizeKey       = @"IQFileSize";
NSString *const IQFileCreateDateKey = @"IQFileCreateDate";
NSString *const IQFileDurationKey   = @"IQFileDurationKey";


static IQProjectVideo *shareObject;

@implementation IQProjectVideo
{
    NSOperationQueue    *_readOperationQueue;
    NSOperationQueue    *_writeOperationQueue;
    
    NSTimer             *_stopTimer;
    NSTimer             *_startTimer;
    
    NSDate *_startDate;
    NSDate *_previousDate;
    NSDate *_currentDate;
    
    AVAssetWriter *videoWriter;
    AVAssetWriterInput* writerInput;
    AVAssetWriterInputPixelBufferAdaptor *adaptor;
    CVPixelBufferRef buffer;
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
    if (self)
    {
        _readOperationQueue = [[NSOperationQueue alloc] init];
        _readOperationQueue.name = @"Read Operation Queue";
        [_readOperationQueue setMaxConcurrentOperationCount:1];
        
        _writeOperationQueue = [[NSOperationQueue alloc] init];
        _writeOperationQueue.name = @"Write Operation Queue";
        [_writeOperationQueue setMaxConcurrentOperationCount:1];
        
        buffer = NULL;
        _path = [NSTemporaryDirectory() stringByAppendingString:@"movie.mov"];
    }
    return self;
}

-(void)cancel
{
    [_startTimer invalidate];
    [_stopTimer invalidate];

    buffer = NULL;
    _completionBlock = NULL;
}

-(void)startCapturingScreenshots
{
    NSBlockOperation *blockOperation = [NSBlockOperation blockOperationWithBlock:^{

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
    
    if (_writeOperationQueue.operationCount)    [blockOperation addDependency:_writeOperationQueue.operations.lastObject];
    [_writeOperationQueue addOperation:blockOperation];
    
    _startDate = [NSDate date];
    _currentDate = _startDate;

    _startTimer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(screenshot) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:_startTimer forMode:NSRunLoopCommonModes];
}

-(void)startVideoCaptureOfDuration:(NSInteger)seconds completionBlock:(CompletionBlock)completionBlock
{
    [self cancel];
    _completionBlock = completionBlock;
    
    [self startCapturingScreenshots];
    
    _stopTimer = [NSTimer scheduledTimerWithTimeInterval:seconds target:self selector:@selector(stopVideoCapture) userInfo:nil repeats:NO];
}

-(void)startVideoCapture
{
    [self cancel];
    
    [self startCapturingScreenshots];
}

-(void)stopVideoCaptureWithCompletionHandler:(CompletionBlock)completionBlock
{
    _completionBlock = completionBlock;
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
UIKIT_EXTERN CGImageRef UIGetScreenImage(void);

-(void)screenshot
{
    CGImageRef screen = UIGetScreenImage();

    _previousDate = _currentDate;
    _currentDate = [NSDate date];

    NSBlockOperation *imageReadOperation = [NSBlockOperation blockOperationWithBlock:^{

        UIImage *image = [[UIImage alloc] initWithCGImage:screen];
        CGImageRelease(screen);

        if (image)
        {
            NSBlockOperation *imageWriteOperation = [NSBlockOperation blockOperationWithBlock:^{
                
                while (writerInput.readyForMoreMediaData == NO)
                {
                    sleep(0.01);
                    continue;
                }
                
                //First time only
                if (buffer == NULL) CVPixelBufferPoolCreatePixelBuffer (NULL, adaptor.pixelBufferPool, &buffer);
                
                buffer = [IQProjectVideo pixelBufferFromCGImage:image.CGImage];
                
                if (buffer)
                {
                    Float64 interval = [_currentDate timeIntervalSinceDate:_startDate];
                    int32_t timeScale = 1.0/([_currentDate timeIntervalSinceDate:_previousDate]);
                    
                    /**/
                    CMTime presentTime=CMTimeMakeWithSeconds(interval, MAX(33, timeScale));
                    //                        NSLog(@"presentTime:%@",(__bridge NSString *)CMTimeCopyDescription(kCFAllocatorDefault, presentTime));
                    
                    // append buffer
                    [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                    CVPixelBufferRelease(buffer);
                }

            }];

            if (_writeOperationQueue.operationCount)    [imageWriteOperation addDependency:_writeOperationQueue.operations.lastObject];
            [_writeOperationQueue addOperation:imageWriteOperation];
        }
    }];
    
    if (_readOperationQueue.operationCount) [imageReadOperation addDependency:_readOperationQueue.operations.lastObject];
    [_readOperationQueue addOperation:imageReadOperation];
}

-(void)markFinishAndWriteMovie
{
    NSBlockOperation *finishOperation = [NSBlockOperation blockOperationWithBlock:^{
        
        //Finish the session:
        [writerInput markAsFinished];
        
        /**
         *  fix bug on iOS7 is not work, finishWritingWithCompletionHandler method is not work
         */
        // http://stackoverflow.com/questions/18885735/avassetwriter-fails-when-calling-finishwritingwithcompletionhandler
        Float64 interval = [_currentDate timeIntervalSinceDate:_startDate];
        
        CMTime cmTime = CMTimeMake(interval, 1);
        [videoWriter endSessionAtSourceTime:cmTime];
        
        if ([videoWriter respondsToSelector:@selector(finishWritingWithCompletionHandler:)])
        {
            NSLog(@"finishWritingWithCompletionHandler");
            [videoWriter finishWritingWithCompletionHandler:^{
                CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
                [self _completed];
            }];
        }
        else
        {
            [videoWriter finishWriting];
            CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
            [self _completed];
        }
    }];
    
    NSLog(@"Read Operations Left: %lu",(unsigned long)_readOperationQueue.operationCount);
    for (NSOperation *readOperation in _readOperationQueue.operations)
    {
        [finishOperation addDependency:readOperation];
    }
    
    NSLog(@"Write Operations Left: %lu",(unsigned long)_writeOperationQueue.operationCount);
    for (NSOperation *writeOperation in _writeOperationQueue.operations)
    {
        [finishOperation addDependency:writeOperation];
    }
    
    [_writeOperationQueue addOperation:finishOperation];
}

- (void)_completed
{
    NSLog(@"%@",NSStringFromSelector(_cmd));

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
    [self cancel];
}

//Helper functions
+ (CVPixelBufferRef)pixelBufferFromCGImage:(CGImageRef) image
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
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    
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
