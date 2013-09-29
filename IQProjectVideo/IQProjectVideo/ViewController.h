//
//  ViewController.h
//  IQProjectVideo
//
//  Created by Iftekhar Mac Pro on 9/29/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ViewController : UIViewController
{
    IBOutlet UIImageView *myImageView;
    IBOutlet UILabel *labelTimeElapsed;
    IBOutlet UIActivityIndicatorView *activityIndicator;
    IBOutlet UIProgressView *progressView;
    IBOutlet UITableView *tableViewDemo;
}

- (IBAction)startRecordingClicked:(UIButton *)sender;


@end
