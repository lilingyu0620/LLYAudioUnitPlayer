//
//  LLYAudioUnitRecord.h
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/7.
//  Copyright © 2018年 lly. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LLYAudioUnitRecord : NSObject

- (void)start;
- (void)stop;
+ (NSString *)recordPath;
@end
