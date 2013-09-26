//
//  IQImagesToMovie.m
//  VideoCreatorDemo
//
//  Created by Iftekhar Mac Pro on 9/26/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.


#import "IQProjectVideo.h"
#import <AVFoundation/AVFoundation.h>

@implementation IQProjectVideo

-(void)makeProjectVideoOfDuration:(NSInteger)seconds savePath:(NSString*)path
{
    _path = path;
    _window = [[UIApplication sharedApplication] keyWindow];
    _images = [[NSMutableArray alloc] init];
    [self performSelector:@selector(stopCapture) withObject:nil afterDelay:seconds];
    [_timer invalidate];
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30.0 target:self selector:@selector(screenshot) userInfo:nil repeats:YES];
}

-(void)screenshot
{
    UIGraphicsBeginImageContext(_window.bounds.size);
    
    [_window.layer.presentationLayer renderInContext:UIGraphicsGetCurrentContext()];
    [_images addObject:UIGraphicsGetImageFromCurrentImageContext()];
    UIGraphicsEndImageContext();
}

-(void)stopCapture
{
    [_timer invalidate];
    [self writeImageAsMovie:_images toPath:_path size:_window.bounds.size];
}

-(void)writeImageAsMovie:(NSArray *)array toPath:(NSString*)path size:(CGSize)size
{
        NSError *error = nil;
        AVAssetWriter *videoWriter = [[AVAssetWriter alloc] initWithURL:[NSURL fileURLWithPath:path]
                                                               fileType:AVFileTypeMPEG4
                                                                  error:&error];
        NSParameterAssert(videoWriter);
        
        NSDictionary *videoSettings = [NSDictionary dictionaryWithObjectsAndKeys:
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
        
        CVPixelBufferRef buffer = NULL;
        buffer = [IQProjectVideo pixelBufferFromCGImage:[[array objectAtIndex:0] CGImage]];
        CVPixelBufferPoolCreatePixelBuffer (NULL, adaptor.pixelBufferPool, &buffer);
        
        [adaptor appendPixelBuffer:buffer withPresentationTime:kCMTimeZero];
        int i = 1;
        while (1)
        {
            if (writerInput.readyForMoreMediaData == NO)
            {
//                NSLog(@"Not Ready");
                sleep(0.01);
                continue;
            }
            else
            {
                CMTime frameTime = CMTimeMake(1, 3);
                CMTime lastTime=CMTimeMake(i, 30);
                CMTime presentTime=CMTimeAdd(lastTime, frameTime);
                
//                NSLog(@"i:%d",i);
                
                if (i >= [array count])     buffer = NULL;
                else                        buffer = [IQProjectVideo pixelBufferFromCGImage:[[array objectAtIndex:i] CGImage]];
                
                //CVBufferRetain(buffer);
                
                if (buffer)
                {
                    // append buffer
                    [adaptor appendPixelBuffer:buffer withPresentationTime:presentTime];
                    i++;
                }
                else
                {
                    NSLog (@"Finished AtPath:%@",path);
                    break;
                }
            }
        }
    
    //Finish the session:
    [writerInput markAsFinished];
    [videoWriter finishWriting];
    CVPixelBufferPoolRelease(adaptor.pixelBufferPool);
    [_images removeAllObjects];
}

//Helper functions
+ (CVPixelBufferRef) pixelBufferFromCGImage: (CGImageRef) image
{
    
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
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
    
    //    CGAffineTransform flipVertical = CGAffineTransformMake(
    //                                                           1, 0, 0, -1, 0, CGImageGetHeight(image)
    //                                                           );
    //    CGContextConcatCTM(context, flipVertical);
    
    
    
    //    CGAffineTransform flipHorizontal = CGAffineTransformMake(
    //                                                             -1.0, 0.0, 0.0, 1.0, CGImageGetWidth(image), 0.0
    //                                                             );
    //
    //    CGContextConcatCTM(context, flipHorizontal);
    
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image),
                                           CGImageGetHeight(image)), image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    return pxbuffer;
}

@end
