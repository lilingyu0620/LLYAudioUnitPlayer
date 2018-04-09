//
//  LLYAUGraphRecord.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/9.
//  Copyright © 2018年 lly. All rights reserved.
//

//播放本地音频+录音+混合+播放
//一步步来 1.先播放本地音频

#import "LLYAUGraphRecord.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

@implementation LLYAUGraphRecord{
    
    AUGraph playerGraph;
    AUNode playerNode;
    AudioUnit playerUnit;
    AudioStreamBasicDescription audioFormat;
    
    NSInputStream *inputStream;
}

- (void)initAudioUnit{
    
    NSURL *url = [NSURL fileURLWithPath:[CommonUtil bundlePath:@"/abc.pcm"]];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"打开文件失败!!!!%@",url);
    }
    else{
        [inputStream open];
    }
    
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil]; // 只有播放
    
    OSStatus status = noErr;
    status = NewAUGraph(&playerGraph);
    CheckStatus(status, @"创建AUGraph失败", YES);
    
    AudioComponentDescription outputAudioDesc;
    outputAudioDesc.componentType = kAudioUnitType_Output;
    outputAudioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputAudioDesc.componentFlags = 0;
    outputAudioDesc.componentFlagsMask = 0;
    
    AUNode outputNode;
    status = AUGraphAddNode(playerGraph, &outputAudioDesc, &outputNode);
    CheckStatus(status, @"绑定node失败", YES);
    
    status = AUGraphOpen(playerGraph);
    CheckStatus(status, @"打开AUGraph失败", YES);
    
    status = AUGraphNodeInfo(playerGraph, outputNode, NULL, &playerUnit);
    CheckStatus(status, @"创建AudioUnit失败", YES);
    
    // audio format
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mBitsPerChannel = 16;
    status = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
    CheckStatus(status, @"设置输入音频数据格式失败", YES);
    status = AudioUnitSetProperty(playerUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(audioFormat));
    CheckStatus(status, @"设置输出音频格式失败", YES);

    
    //callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = LLYPlayCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(playerUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));
    
    status  = AUGraphInitialize(playerGraph);
    CheckStatus(status, @"Graph初始化失败", YES);
    status = AUGraphStart(playerGraph);
    CheckStatus(status, @"Graph start失败", YES);
    
}

static OSStatus LLYPlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){
    
    __unsafe_unretained LLYAUGraphRecord *play = (__bridge LLYAUGraphRecord *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[play->inputStream read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [play stop];
        });
    }
    return noErr;
}


static void CheckStatus(OSStatus status, NSString *message, BOOL fatal)
{
    if(status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if(fatal)
            exit(-1);
    }
}


- (void)stop{
    
    CheckStatus(AUGraphStop(playerGraph), @"停止Graph失败", YES);
    CheckStatus(AUGraphUninitialize(playerGraph), @"回收Graph失败", YES);
    [inputStream close];
}
- (void)start{
    [self initAudioUnit];
}

@end
