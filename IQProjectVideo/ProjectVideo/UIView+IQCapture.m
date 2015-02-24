//
//  UIView+IQCapture.m
//  IQProjectVideo
//
//  Created by xandrucea on 24.02.15.
//  Copyright (c) 2015 Iftekhar. All rights reserved.
//  Source: http://stackoverflow.com/a/19498464/1141395

#import "UIView+IQCapture.h"

@implementation UIView (IQCapture)

- (UIImage *)imageByRenderingViewOpaque:(BOOL)yesOrNo
{
    UIGraphicsBeginImageContextWithOptions(self.bounds.size, yesOrNo, 0);
    if( [[UIDevice currentDevice] systemVersion].integerValue >= 7.0 )
    {
        [self drawViewHierarchyInRect:self.bounds afterScreenUpdates:NO];
    }
    
    else
    {
        [self.layer renderInContext:UIGraphicsGetCurrentContext()];
    }
    
    UIImage *resultingImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resultingImage;
}

- (UIImage *)imageByRenderingViewOpaque{
    return [self imageByRenderingViewOpaque:NO];
}

@end
