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

@interface ViewController ()<UIGestureRecognizerDelegate,UITextFieldDelegate,UITableViewDataSource,UITableViewDelegate>

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


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    
    if (cell == nil)
    {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        [cell.textLabel setTextAlignment:NSTextAlignmentCenter];
    }
    
    [cell.textLabel setText:[NSString stringWithFormat:@"  {  %d  ,  %d  }  ",indexPath.row,indexPath.section]];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}


-(void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [[[UIApplication sharedApplication] keyWindow] setNeedsDisplay];
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
        [projectVideo startVideoCapture];
        [progressView setProgress:0 animated:NO];
        recordStartTime = [NSDate date];
        timerRecord = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(updateTimeElapsed) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:timerRecord forMode:NSRunLoopCommonModes];
    }
    //Start recording video.
    else
    {
        [sender setEnabled:NO];
        [timerRecord invalidate];
        [activityIndicator startAnimating];
        [projectVideo stopVideoCaptureWithProgress:^(CGFloat progress) {
            [progressView setProgress:progress animated:YES];
        } CompletionHandler:^(NSDictionary *info, NSError *error) {
       
            NSLog(@"%@",info);
            sender.tag = 0;
            [sender setTitle:@"Start Recording" forState:UIControlStateNormal];
            [sender setEnabled:YES];
        }];
    }
    
}

- (void)viewDidUnload {
    tableViewDemo = nil;
    [super viewDidUnload];
}

@end
