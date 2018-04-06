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

@implementation LLYAudioUnitPlayer{
    AudioUnit playerAudioUnit;
    NSInputStream *inputStream;
    AudioBufferList *bufferList;
}

- (void)initAudioUnit{
    
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"pcm"];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"打开文件失败!!!!%@",url);
    }
    else{
        [inputStream open];
    }
    
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
    
    //AudioUnit裸创建
    AudioComponent audioComponent = AudioComponentFindNext(NULL, &audioUnitDesc);
    AudioComponentInstanceNew(audioComponent, &playerAudioUnit);
    
    //缓存buffer
    bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(BUFFER_SIZE);
    
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

    OSStatus result = AudioUnitInitialize(playerAudioUnit);
    NSLog(@"result = %d",result);
    
}

- (void)play{
    
    [self initAudioUnit];
    
    AudioOutputUnitStart(playerAudioUnit);
}

- (void)stop{
    
    AudioOutputUnitStop(playerAudioUnit);
    
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
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

- (void)printAudioStreamBasicDescription:(AudioStreamBasicDescription)asbd {
    char formatID[5];
    UInt32 mFormatID = CFSwapInt32HostToBig(asbd.mFormatID);
    bcopy (&mFormatID, formatID, 4);
    formatID[4] = '\0';
    printf("Sample Rate:         %10.0f\n",  asbd.mSampleRate);
    printf("Format ID:           %10s\n",    formatID);
    printf("Format Flags:        %10X\n",    (unsigned int)asbd.mFormatFlags);
    printf("Bytes per Packet:    %10d\n",    (unsigned int)asbd.mBytesPerPacket);
    printf("Frames per Packet:   %10d\n",    (unsigned int)asbd.mFramesPerPacket);
    printf("Bytes per Frame:     %10d\n",    (unsigned int)asbd.mBytesPerFrame);
    printf("Channels per Frame:  %10d\n",    (unsigned int)asbd.mChannelsPerFrame);
    printf("Bits per Channel:    %10d\n",    (unsigned int)asbd.mBitsPerChannel);
    printf("\n");
}
@end
