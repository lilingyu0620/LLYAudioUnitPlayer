//
//  ViewController.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/6.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "ViewController.h"
#import "LLYAudioUnitPlayer.h"
#import "PAirSandbox.h"
#import "LLYAudioUnitRecord.h"
#import "CommonUtil.h"
#import "LLYAudioUnitConverter.h"
#import "LLYAudioUnitExtPlayer.h"
#import "LLYAUGraphRecord.h"
#import "LLYVideoPlayerViewController.h"
#import "LLYAudioQueuePlayer.h"
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import "LLYAudioUnitEffect.h"

@interface ViewController ()<CAAnimationDelegate>

@property(nonatomic,strong)LLYAudioUnitPlayer *player;
@property(nonatomic,strong)LLYAudioUnitRecord *record;
@property (nonatomic, strong) LLYAudioUnitConverter *converter;
@property (nonatomic, strong) LLYAudioUnitExtPlayer *extPlayer;
@property (nonatomic, strong) LLYAUGraphRecord *auGraphPlayer;
@property (nonatomic, strong) LLYAudioQueuePlayer *audioQueuePlayer;
@property (nonatomic, strong) LLYAudioUnitEffect *audioUnitEffect;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a ni
    [[PAirSandbox sharedInstance] showSandboxBrowser];
}

- (IBAction)playPCM:(id)sender {
    
    NSString *abcPCMPath = [CommonUtil bundlePath:@"/test.pcm"];
    self.player = [[LLYAudioUnitPlayer alloc]initWithPCMPath:abcPCMPath];
    [self.player play];
}

- (IBAction)startRecord:(id)sender {
    self.record = [[LLYAudioUnitRecord alloc]init];
    [self.record start];
}

- (IBAction)stopRecord:(id)sender {
    [self.record stop];
}
- (IBAction)playRecord:(id)sender {
    self.player = [[LLYAudioUnitPlayer alloc]initWithPCMPath:[LLYAudioUnitRecord recordPath]];
    [self.player play];
}
- (IBAction)playMP3:(id)sender {
    self.converter = [[LLYAudioUnitConverter alloc]init];
    [self.converter play];
}
- (IBAction)extPlayMp3:(id)sender {
    self.extPlayer = [[LLYAudioUnitExtPlayer alloc]init];
    [self.extPlayer play];
}
- (IBAction)auGraphPlayer:(id)sender {
    self.auGraphPlayer = [[LLYAUGraphRecord alloc]init];
    [self.auGraphPlayer start];
}
- (IBAction)videoPlayer:(id)sender {
    
    LLYVideoPlayerViewController *videoPlayerVC = [[LLYVideoPlayerViewController alloc]init];
    [self presentViewController:videoPlayerVC animated:YES completion:nil];
}

- (IBAction)audioQueuePlayer:(id)sender {
    
    self.audioQueuePlayer = [[LLYAudioQueuePlayer alloc]initWithAudioFilePath:[CommonUtil bundlePath:@"/abc.mp3"]];
//    [self.audioQueuePlayer startPlay];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
       [self.audioQueuePlayer llystartPlay];
    });
    
}

- (IBAction)audioUnitEffect:(id)sender {
    
    self.audioUnitEffect = [[LLYAudioUnitEffect alloc]init];
    [self.audioUnitEffect start];
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
