//
//  LLYAudioPlayer.h
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/11.
//  Copyright © 2018年 lly. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioUnit/AudioUnit.h>

@protocol LLYAudioPlayerDelegate <NSObject>

- (AudioBufferList *)audioData;

@end


@interface LLYAudioPlayer : NSObject

@property (nonatomic, weak) id<LLYAudioPlayerDelegate> delegate;

- (void)initAudioUnitWithOutputASBD:(AudioStreamBasicDescription)outputFormat;

- (void)play;

@end
