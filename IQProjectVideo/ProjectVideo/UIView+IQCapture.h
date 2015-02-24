//
//  UIView+IQCapture.h
//  IQProjectVideo
//
//  Created by xandrucea on 24.02.15.
//  Copyright (c) 2015 Iftekhar. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIView (IQCapture)

- (UIImage *)imageByRenderingViewOpaque:(BOOL)yesOrNo;

- (UIImage *)imageByRenderingViewOpaque;

@end
