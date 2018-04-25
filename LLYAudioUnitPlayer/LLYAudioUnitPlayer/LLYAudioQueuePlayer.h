//
//  LLYAudioQueuePlayer.h
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/16.
//  Copyright © 2018年 lly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LLYAudioQueuePlayer : NSObject

- (instancetype)initWithAudioFilePath:(NSString *)audioFilePath;

- (void)startPlay;

- (void)llystartPlay;

- (void)pause;

- (void)stop;

@end
