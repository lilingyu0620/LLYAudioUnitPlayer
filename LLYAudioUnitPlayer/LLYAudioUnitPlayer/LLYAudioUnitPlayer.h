//
//  LLYAudioUnitPlayer.h
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/6.
//  Copyright © 2018年 lly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LLYAudioUnitPlayer : NSObject

- (instancetype)initWithPCMPath:(NSString *)pcmPath;

- (void)play;

@end
