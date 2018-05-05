//
//  LLYAudioUnitEffect.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/5/5.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioUnitEffect.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

#define EF_GRAPH_CONST_BUFFER_SIZE 2048*2*10

@interface LLYAudioUnitEffect (){
    
    AUGraph playerGraph;
    
    //负责播放和录音
    AUNode ioNode;
    AudioUnit ioUnit;
    //负责音效
    AUNode effectNode;
    AudioUnit effectUnit;
    
    AudioBufferList *buffList;
    Byte *buffer;
    
    AudioStreamBasicDescription audioFormat;
    
    NSInputStream *inputStream;
}


@end

@implementation LLYAudioUnitEffect

- (void)initAudioUnit{
    
    NSURL *url = [NSURL fileURLWithPath:[CommonUtil bundlePath:@"/abc.pcm"]];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"打开文件失败!!!!%@",url);
    }
    else{
        [inputStream open];
    }
    
    // buffer
    uint32_t numberBuffers = 1;
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = numberBuffers;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = EF_GRAPH_CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(EF_GRAPH_CONST_BUFFER_SIZE);
    buffer = malloc(EF_GRAPH_CONST_BUFFER_SIZE);
    
    
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    [audioSession setPreferredIOBufferDuration:0.02 error:&error];
    
    // audio format
    audioFormat.mSampleRate = 44100;
    audioFormat.mFormatID = kAudioFormatLinearPCM;
    audioFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 1;
    audioFormat.mBytesPerPacket = 2;
    audioFormat.mBytesPerFrame = 2;
    audioFormat.mBitsPerChannel = 16;
    
    OSStatus status = noErr;
    status = NewAUGraph(&playerGraph);
    CheckStatus(status, @"创建AUGraph失败", YES);
    //先打开才能用
    status = AUGraphOpen(playerGraph);
    CheckStatus(status, @"打开AUGraph失败", YES);
    
    //播放
    AudioComponentDescription outputAudioDesc;
    outputAudioDesc.componentType = kAudioUnitType_Output;
    outputAudioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    outputAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    outputAudioDesc.componentFlags = 0;
    outputAudioDesc.componentFlagsMask = 0;
    
    status = AUGraphAddNode(playerGraph, &outputAudioDesc, &ioNode);
    CheckStatus(status, @"绑定ionode失败", YES);
    
    status = AUGraphNodeInfo(playerGraph, ioNode, NULL, &ioUnit);
    CheckStatus(status, @"创建ioAudioUnit失败", YES);
    
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(AudioStreamBasicDescription));
    CheckStatus(status, @"设置输入音频格式失败", YES);
    
    status = AudioUnitSetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(AudioStreamBasicDescription));
    CheckStatus(status, @"设置输出音频格式失败", YES);
    
//    UInt32 flag = 1;
//    status = AudioUnitSetProperty(ioUnit,
//                                  kAudioOutputUnitProperty_EnableIO,
//                                  kAudioUnitScope_Input,
//                                  1,
//                                  &flag,
//                                  sizeof(flag));
//    CheckStatus(status, @"设置输入能力失败", YES);
    
    //混合相关
    AudioComponentDescription effectAudioDesc;
    effectAudioDesc.componentType = kAudioUnitType_Effect;
    effectAudioDesc.componentSubType = kAudioUnitSubType_Reverb2;
    effectAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    effectAudioDesc.componentFlags = 0;
    effectAudioDesc.componentFlagsMask = 0;
    
    status = AUGraphAddNode(playerGraph, &effectAudioDesc, &effectNode);
    CheckStatus(status, @"绑定混合node失败", YES);
    
    status = AUGraphNodeInfo(playerGraph, effectNode, NULL, &effectUnit);
    CheckStatus(status, @"创建混合AudioUnit失败", YES);
    
//    status = AudioUnitSetProperty(effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &audioFormat, sizeof(AudioStreamBasicDescription));
//    CheckStatus(status, @"设置音效输出格式失败", YES);
    
//    status = AudioUnitSetProperty(effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(AudioStreamBasicDescription));
//    CheckStatus(status, @"设置音效输入格式失败", YES);
 
//    status = AudioUnitSetParameter(effectUnit, kAudioUnitSubType_NewTimePitch, kAudioUnitScope_Input, 0, 2, 0);
//    CheckStatus(status, @"设置变声参数失败", YES);
    
    //绑定nodes
    status = AUGraphConnectNodeInput(playerGraph, effectNode, 0, ioNode, 0);
    CheckStatus(status, @"绑定node失败", YES);

    AURenderCallbackStruct effectInputCallbackStruct;
    effectInputCallbackStruct.inputProc = EffectInputPlayCallback;
    effectInputCallbackStruct.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(effectUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &effectInputCallbackStruct, sizeof(effectInputCallbackStruct));
    CheckStatus(status, @"effectUnit绑定回调失败", YES);
    
    //callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = PlayCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callbackStruct, sizeof(callbackStruct));
    CheckStatus(status, @"ioUnit绑定回调失败", YES);

    
    status  = AUGraphInitialize(playerGraph);
    CheckStatus(status, @"Graph初始化失败", YES);
    status = AUGraphStart(playerGraph);
    CheckStatus(status, @"Graph start失败", YES);
    
}


static OSStatus EffectInputPlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){
    
    __unsafe_unretained LLYAudioUnitEffect *play = (__bridge LLYAudioUnitEffect *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[play->inputStream read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    return noErr;
}

static OSStatus PlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){
    
    __unsafe_unretained LLYAudioUnitEffect *play = (__bridge LLYAudioUnitEffect *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[play->inputStream read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
//    if (ioData->mBuffers[0].mDataByteSize <= 0) {
//        dispatch_async(dispatch_get_main_queue(), ^{
//            [play stop];
//        });
//    }
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


- (void)start{
    [self initAudioUnit];
}
@end
