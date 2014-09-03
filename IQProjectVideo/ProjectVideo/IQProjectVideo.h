//
//  IQProjectVideo
//
//  Created by Iftekhar Mac Pro on 9/26/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^CompletionBlock)(NSDictionary* info, NSError* error);

//This class uses a Private API function 'UIGetScreenImage(void) to capture images. This class should not be used for App Store app.
@interface IQProjectVideo : NSObject
{
    NSString        *_path;
    CompletionBlock _completionBlock;
}

+(IQProjectVideo*)sharedController;

//Start capturing video of screen. Automatically call stopVideoCapture after 'seconds' parameter.
-(void)startVideoCaptureOfDuration:(NSInteger)seconds completionBlock:(CompletionBlock)completionBlock;

//Start capturing video of screen. You need to manually call stopVideoCapture to stop video capture.
-(void)startVideoCapture;

//Stop video capture.
-(void)stopVideoCaptureWithCompletionHandler:(CompletionBlock)completionBlock;

//Cancel video capture.
-(void)cancel;


@end


extern NSString *const IQFilePathKey;
extern NSString *const IQFileSizeKey;
extern NSString *const IQFileCreateDateKey;
extern NSString *const IQFileDurationKey;
