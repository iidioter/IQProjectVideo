//
//  IQImagesToMovie.h
//  VideoCreatorDemo
//
//  Created by Iftekhar Mac Pro on 9/26/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface IQProjectVideo : NSObject
{
    NSMutableArray  *_images;
    NSTimer         *_timer;
    UIWindow        *_window;
    NSString        *_path;
}

-(void)makeProjectVideoOfDuration:(NSInteger)seconds savePath:(NSString*)path;

@end
