//
//  LLYAudioUnitPlayer.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/6.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioUnitPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>

const uint32_t BUFFER_SIZE = 0x10000;

@interface LLYAudioUnitPlayer ()

@property(nonatomic,copy)NSString *pcmPath;

@end

@implementation LLYAudioUnitPlayer{
    AudioUnit playerAudioUnit;
    AudioUnit effectAuidoUnit;
    NSInputStream *inputStream;
    AudioBufferList *bufferList;
}

- (instancetype)initWithPCMPath:(NSString *)pcmPath{
    self = [super init];
    if (self) {
        self.pcmPath = pcmPath;
    }
    return self;
}

- (void)initAudioUnit{
    
    NSURL *url = [NSURL fileURLWithPath:self.pcmPath];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"打开文件失败!!!!%@",url);
    }
    else{
        [inputStream open];
    }
    
    // BUFFER
    bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(BUFFER_SIZE);
    
    //设置audiosession
    NSError *error = nil;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    //AU描述
    AudioComponentDescription audioUnitDesc;
    audioUnitDesc.componentType = kAudioUnitType_Output;
    audioUnitDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioUnitDesc.componentFlags = 0;
    audioUnitDesc.componentFlagsMask = 0;
    
    AudioComponentDescription effectAuidoUnitDesc;
    effectAuidoUnitDesc.componentType = kAudioUnitType_Effect;
    effectAuidoUnitDesc.componentSubType = kAudioUnitSubType_Reverb2;
    effectAuidoUnitDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    effectAuidoUnitDesc.componentFlags = 0;
    effectAuidoUnitDesc.componentFlagsMask = 0;
    
    
    //AudioUnit裸创建
    AudioComponent audioComponent = AudioComponentFindNext(NULL, &audioUnitDesc);
    AudioComponentInstanceNew(audioComponent, &playerAudioUnit);
    
    AudioComponent effectCompenent = AudioComponentFindNext(NULL, &effectAuidoUnitDesc);
    AudioComponentInstanceNew(effectCompenent, &effectAuidoUnit);
    
    
    //通用参数设置,这里是设置扬声器
    OSStatus status = noErr;
    UInt32 flag = 1;
    UInt32 outputBus = 0;//Element 0
    status = AudioUnitSetProperty(playerAudioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, outputBus, &flag, sizeof(flag));
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status:%d", status);
    }
    
    
    //设置音频具体结构
    AudioStreamBasicDescription audioStreamDesc;
//    bzero(&audioStreamDesc, sizeof(audioStreamDesc));
    memset(&audioStreamDesc, 0, sizeof(audioStreamDesc));
    audioStreamDesc.mFormatID = kAudioFormatLinearPCM;
    audioStreamDesc.mSampleRate = 44100;//采样率
    audioStreamDesc.mChannelsPerFrame = 1;//声道数
    audioStreamDesc.mFramesPerPacket = 1;//每帧只有一个packet
    audioStreamDesc.mFormatFlags = kLinearPCMFormatFlagIsSignedInteger;//kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;
    audioStreamDesc.mBitsPerChannel = 16;//位深
    audioStreamDesc.mBytesPerFrame = 2;
    audioStreamDesc.mBytesPerPacket = 2;

    status = AudioUnitSetProperty(playerAudioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, outputBus, &audioStreamDesc,sizeof(audioStreamDesc));
    if (status) {
        NSLog(@"AudioUnitSetProperty error with status:%d", status);
    }
    
    
    //callback
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = PlayCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(playerAudioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, outputBus, &callbackStruct, sizeof(callbackStruct));

    
    AURenderCallbackStruct efcallbackStruct;
    efcallbackStruct.inputProc = EffectAudioUnitRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void*)self;
    status = AudioUnitSetProperty(effectAuidoUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Global,
                                  0,
                                  &efcallbackStruct,
                                  sizeof(efcallbackStruct));
    
    OSStatus result = AudioUnitInitialize(playerAudioUnit);
    NSLog(@"result = %d",result);
    result = AudioUnitInitialize(effectAuidoUnit);
    NSLog(@"result = %d",result);
    
}

- (void)play{
    
    [self initAudioUnit];
    
    AudioOutputUnitStart(playerAudioUnit);
    AudioOutputUnitStart(effectAuidoUnit);
}

- (void)stop{
    
    AudioOutputUnitStop(playerAudioUnit);
    AudioOutputUnitStop(effectAuidoUnit);
    [inputStream close];
}


static OSStatus PlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){

    __unsafe_unretained LLYAudioUnitPlayer *play = (__bridge LLYAudioUnitPlayer *)inRefCon;

    ioData->mBuffers[0].mDataByteSize = (UInt32)[play->inputStream read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);

    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [play stop];
        });
    }
    return noErr;
}

static OSStatus EffectAudioUnitRenderCallback(void *inRefCon,
                                          AudioUnitRenderActionFlags *ioActionFlags,
                                          const AudioTimeStamp *inTimeStamp,
                                          UInt32 inBusNumber,
                                          UInt32 inNumberFrames,
                                          AudioBufferList *ioData){
    __unsafe_unretained LLYAudioUnitPlayer *play = (__bridge LLYAudioUnitPlayer *)inRefCon;
    ioData->mBuffers[0].mDataByteSize = (UInt32)[play->inputStream read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"out size: %d", ioData->mBuffers[0].mDataByteSize);
    
    return noErr;
}
@end
