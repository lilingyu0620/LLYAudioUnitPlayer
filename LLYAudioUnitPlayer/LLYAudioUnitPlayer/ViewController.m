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

@interface ViewController ()

@property(nonatomic,strong)LLYAudioUnitPlayer *player;
@property(nonatomic,strong)LLYAudioUnitRecord *record;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a ni
}

- (IBAction)playPCM:(id)sender {
    
    NSString *abcPCMPath = [CommonUtil bundlePath:@"/abc.pcm"];
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

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
