//
//  LLYAUGraphRecord.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/9.
//  Copyright © 2018年 lly. All rights reserved.
//

//播放本地音频+录音+混合+播放
//一步步来 1.先播放本地音频
//2.加入录音功能
//3.将录音音频和本地音频送给mix mix的输出绑定给io的输出 done.

#import "LLYAUGraphRecord.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

#define GRAPH_CONST_BUFFER_SIZE 2048*2*10


@implementation LLYAUGraphRecord{
    
    AUGraph playerGraph;
    
    //负责播放和录音
    AUNode ioNode;
    AudioUnit ioUnit;
    //负责混合
    AUNode mixNode;
    AudioUnit mixUnit;
    
    AudioBufferList *buffList;
    Byte *buffer;

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
    
    // buffer
    uint32_t numberBuffers = 1;
    buffList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    buffList->mNumberBuffers = numberBuffers;
    buffList->mBuffers[0].mNumberChannels = 1;
    buffList->mBuffers[0].mDataByteSize = GRAPH_CONST_BUFFER_SIZE;
    buffList->mBuffers[0].mData = malloc(GRAPH_CONST_BUFFER_SIZE);
    buffer = malloc(GRAPH_CONST_BUFFER_SIZE);
    

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
    
    //播放和录音
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
    
    //    UInt32 iomaximumFramesPerSlice = 1024;
    //    status = AudioUnitSetProperty (ioUnit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&iomaximumFramesPerSlice,sizeof (iomaximumFramesPerSlice));
    //    CheckStatus(status, @"设置io输出音频帧最大值格式失败", YES);
    
    UInt32 flag = 1;
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  1,
                                  &flag,
                                  sizeof(flag));
    CheckStatus(status, @"设置输入能力失败", YES);
    
    //混合相关
    AudioComponentDescription mixAudioDesc;
    mixAudioDesc.componentType = kAudioUnitType_Mixer;
    mixAudioDesc.componentSubType = kAudioUnitSubType_MultiChannelMixer;
    mixAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    mixAudioDesc.componentFlags = 0;
    mixAudioDesc.componentFlagsMask = 0;
    
    status = AUGraphAddNode(playerGraph, &mixAudioDesc, &mixNode);
    CheckStatus(status, @"绑定混合node失败", YES);
    
    status = AUGraphNodeInfo(playerGraph, mixNode, NULL, &mixUnit);
    CheckStatus(status, @"创建混合AudioUnit失败", YES);

    //绑定nodes
    status = AUGraphConnectNodeInput(playerGraph, mixNode, 0, ioNode, 0);
    CheckStatus(status, @"绑定node失败", YES);

    //设置bus数
    UInt32 busCount = 2;
    status = AudioUnitSetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, sizeof(busCount));
    CheckStatus(status, @"设置声道数失败", YES);
    
//    UInt32 size = sizeof(UInt32);
//    CheckStatus(AudioUnitGetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &busCount, &size), @"get property fail",YES);
//    CheckStatus(AudioUnitGetProperty(mixUnit, kAudioUnitProperty_ElementCount, kAudioUnitScope_Global, 1, &busCount, &size), @"get property fail",YES);
    
    //设置多bus的回调
//    for (int i = 0; i < busCount; ++i) {
//        AURenderCallbackStruct rcbs;
//        rcbs.inputProc = &mixInputCallback;
//        rcbs.inputProcRefCon = (__bridge void * _Nullable)(self);
//
//        status = AUGraphSetNodeInputCallback(playerGraph, mixNode, i, &rcbs);
//        CheckStatus(status, @"绑定回调失败", YES);
//
//        status = AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, i, &audioFormat, sizeof(AudioStreamBasicDescription));
//        CheckStatus(status, @"置混合音频输入数据格式失败", YES);
//    }

    //设置混合的输入格式,有多条输入
    //bus0
    status = AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &audioFormat, sizeof(audioFormat));
    CheckStatus(status, @"设置混合音频输入数据格式失败", YES);
    //bus1
    status = AudioUnitSetProperty(mixUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 1, &audioFormat, sizeof(audioFormat));
    CheckStatus(status, @"设置混合音频输入数据格式失败", YES);
    
//    UInt32 mixmaximumFramesPerSlice = 4096;
//    status = AudioUnitSetProperty (ioUnit,kAudioUnitProperty_MaximumFramesPerSlice,kAudioUnitScope_Global,0,&mixmaximumFramesPerSlice,sizeof (mixmaximumFramesPerSlice));
//    CheckStatus(status, @"设置mix输出音频帧最大值格式失败", YES);
    
    //callback
//    AURenderCallbackStruct inputCallbackStruct;
//    inputCallbackStruct.inputProc = InputPlayCallback;
//    inputCallbackStruct.inputProcRefCon = (__bridge void *)self;
//    AudioUnitSetProperty(ioUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &inputCallbackStruct, sizeof(inputCallbackStruct));
//    status = AUGraphSetNodeInputCallback(playerGraph, ioNode, 0, &inputCallbackStruct);
//    CheckStatus(status, @"Graph绑定回调函数失败", YES);

    AURenderCallbackStruct outputCallbackStruct;
    outputCallbackStruct.inputProc = OutputPlayCallback;
    outputCallbackStruct.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(ioUnit, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Output, 1, &outputCallbackStruct, sizeof(outputCallbackStruct));
    CheckStatus(status, @"ioUnit绑定回调失败", YES);
    
    //获取背景音频数据
    AURenderCallbackStruct callback0;
    callback0.inputProc = mixCallback0;
    callback0.inputProcRefCon = (__bridge void *)self;
//    status = AUGraphSetNodeInputCallback(playerGraph, mixNode, 0, &callback0);
    CheckStatus(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &callback0, sizeof(callback0)), @"add mix callback fail",YES);

    //获取录音数据
    AURenderCallbackStruct callback1;
    callback1.inputProc = mixCallback1;
    callback1.inputProcRefCon = (__bridge void *)self;
//    status = AUGraphSetNodeInputCallback(playerGraph, mixNode, 1, &callback1);
    CheckStatus(AudioUnitSetProperty(mixUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 1, &callback1, sizeof(callback1)), @"add mix callback fail",YES);
    
    status  = AUGraphInitialize(playerGraph);
    CheckStatus(status, @"Graph初始化失败", YES);
    status = AUGraphStart(playerGraph);
    CheckStatus(status, @"Graph start失败", YES);
    
}

static OSStatus mixCallback0(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    __unsafe_unretained LLYAUGraphRecord *play = (__bridge LLYAUGraphRecord *)inRefCon;
    
    ioData->mBuffers[0].mDataByteSize = (UInt32)[play->inputStream read:ioData->mBuffers[0].mData maxLength:(NSInteger)ioData->mBuffers[0].mDataByteSize];
    NSLog(@"audio size: %d", ioData->mBuffers[0].mDataByteSize);
    
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [play stop];
        });
    }
    return noErr;
}

static OSStatus mixCallback1(void *inRefCon, AudioUnitRenderActionFlags *ioActionFlags, const AudioTimeStamp *inTimeStamp, UInt32 inBusNumber, UInt32 inNumberFrames, AudioBufferList *ioData) {
    
    __unsafe_unretained LLYAUGraphRecord *play = (__bridge LLYAUGraphRecord *)inRefCon;

    memcpy(ioData->mBuffers[0].mData, play->buffList->mBuffers[0].mData, play->buffList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = play->buffList->mBuffers[0].mDataByteSize;
    
    NSLog(@"record size: %d", ioData->mBuffers[0].mDataByteSize);

    return noErr;
}

static OSStatus InputPlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){

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

static OSStatus OutputPlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){
    
    __unsafe_unretained LLYAUGraphRecord *play = (__bridge LLYAUGraphRecord *)inRefCon;
    
    play->buffList->mNumberBuffers = 1;
    OSStatus status = AudioUnitRender(play->ioUnit, ioActionFlag, inTimeStamp, inBusNumber, inNumberFrames, play->buffList);
    CheckStatus(status, @"获取录音音频失败", YES);
    
//    NSLog(@"record size %d:",play->buffList->mBuffers[0].mDataByteSize);
    
    //将录音写入文件
    
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
    
    if (buffList != NULL) {
        if (buffList->mBuffers[0].mData) {
            free(buffList->mBuffers[0].mData);
            buffList->mBuffers[0].mData = NULL;
        }
        free(buffList);
        buffList = NULL;
    }
    
    [inputStream close];
    CheckStatus(DisposeAUGraph(playerGraph), @"DisposeGraph失败", YES);
}
- (void)start{
    [self initAudioUnit];
}

@end
