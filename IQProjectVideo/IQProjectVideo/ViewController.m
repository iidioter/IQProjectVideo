//
//  ViewController.m
//  IQProjectVideo
//
//  Created by Iftekhar Mac Pro on 9/29/13.
//  Copyright (c) 2013 Iftekhar. All rights reserved.
//

#import "ViewController.h"
#import "InfoViewController.h"
#import "IQProjectVideo.h"

@interface ViewController ()<UIGestureRecognizerDelegate,UITextFieldDelegate>

@end

@implementation ViewController
{
    IQProjectVideo *projectVideo;
    NSDate* recordStartTime;
    NSTimer* timerRecord;
}
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setTitle:@"IQProjectVideo"];

    //Adding barButton to navigationBar
    {
        UIButton *button = [UIButton buttonWithType:UIButtonTypeInfoLight];
        [button addTarget:self action:@selector(infoButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
        
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithCustomView:button];
        [self.navigationItem setRightBarButtonItem:item animated:YES];
    }
    
    //Adding gesture recognizer on demo image.
    {
        UIRotationGestureRecognizer *rotateGesture = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(rotateGestureRecognized:)];
        rotateGesture.delegate = self;
        UIPinchGestureRecognizer *pinchGesture = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(pinchGestureRecognized:)];
        pinchGesture.delegate = self;
        [myImageView addGestureRecognizer:rotateGesture];
        [myImageView addGestureRecognizer:pinchGesture];
    }
}

#pragma mark - Gesture recognizer delegate and selector
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

-(void)rotateGestureRecognized:(UIRotationGestureRecognizer*)gesture
{
    [myImageView setTransform:CGAffineTransformRotate(myImageView.transform, gesture.rotation)];
    gesture.rotation = 0;
}

-(void)pinchGestureRecognized:(UIPinchGestureRecognizer*)gesture
{
    [myImageView setTransform:CGAffineTransformScale(myImageView.transform, gesture.scale, gesture.scale)];
    gesture.scale = 1.0;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

-(void)infoButtonClicked:(UIButton*)button
{
    InfoViewController *info = [[InfoViewController alloc] init];
    [info setModalTransitionStyle:UIModalTransitionStyleFlipHorizontal];
    [self presentViewController:info animated:YES completion:nil];
}

-(BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

-(void)updateTimeElapsed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval timeInterval = [[NSDate date] timeIntervalSinceDate:recordStartTime];
        [labelTimeElapsed setText:[NSString stringWithFormat:@"Time Elapsed: %d Sec", (int)timeInterval]];
    });
}

- (IBAction)startRecordingClicked:(UIButton *)sender {
    
    
    //Start recording video.
    if (sender.tag == 0)
    {
        sender.tag = 1;
        [sender setTitle:@"Stop Recording" forState:UIControlStateNormal];
        projectVideo = [[IQProjectVideo alloc] init];
        [projectVideo startVideoCaptureWithSavePath:[NSTemporaryDirectory() stringByAppendingString:@"movie.mov"]];
        [progressView setProgress:0 animated:NO];
        recordStartTime = [NSDate date];
        timerRecord = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeElapsed) userInfo:nil repeats:YES];
    }
    //Start recording video.
    else
    {
        [sender setUserInteractionEnabled:NO];
        [timerRecord invalidate];
        [activityIndicator startAnimating];
        [projectVideo stopVideoCaptureWithProgress:^(CGFloat progress){
            if (progress == 1)
            {
                [activityIndicator stopAnimating];
            }
            else
            {
                [progressView setProgress:progress animated:YES];
            }
        } completionHandler:^(NSDictionary *fileInfo) {
            [labelTimeElapsed setText:[NSString stringWithFormat:@"File Size:%@",[fileInfo objectForKey:IQFileSizeKey]]];
            sender.tag = 0;
            [sender setTitle:@"Start Recording" forState:UIControlStateNormal];
            [sender setUserInteractionEnabled:YES];
        }];
    }
    
}

- (void)viewDidUnload {
    [super viewDidUnload];
}

@end
