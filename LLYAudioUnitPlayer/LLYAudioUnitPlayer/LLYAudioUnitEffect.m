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
    audioFormat.mFormatFlags = kAudioFormatFlagsNativeFloatPacked | kAudioFormatFlagIsNonInterleaved;//kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    audioFormat.mFramesPerPacket = 1;
    audioFormat.mChannelsPerFrame = 2;
    audioFormat.mBytesPerPacket = 4;
    audioFormat.mBytesPerFrame = 4;
    audioFormat.mBitsPerChannel = 32;
    
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
    effectAudioDesc.componentSubType = kAudioUnitSubType_NBandEQ;
    effectAudioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    effectAudioDesc.componentFlags = 0;
    effectAudioDesc.componentFlagsMask = 0;
    
    status = AUGraphAddNode(playerGraph, &effectAudioDesc, &effectNode);
    CheckStatus(status, @"绑定混合node失败", YES);
    
    status = AUGraphNodeInfo(playerGraph, effectNode, NULL, &effectUnit);
    CheckStatus(status, @"创建混合AudioUnit失败", YES);

//混响器效果（木有声音。。。。）
//    // Global, CrossFade, 0->100, 100
//    kReverb2Param_DryWetMix                         = 0,
//    // Global, Decibels, -20->20, 0
//    kReverb2Param_Gain                                = 1,
//
//    // Global, Secs, 0.0001->1.0, 0.008
//    kReverb2Param_MinDelayTime                        = 2,
//    // Global, Secs, 0.0001->1.0, 0.050
//    kReverb2Param_MaxDelayTime                        = 3,
//    // Global, Secs, 0.001->20.0, 1.0
//    kReverb2Param_DecayTimeAt0Hz                    = 4,
//    // Global, Secs, 0.001->20.0, 0.5
//    kReverb2Param_DecayTimeAtNyquist                = 5,
//    // Global, Integer, 1->1000
//    kReverb2Param_RandomizeReflections                = 6,
    
//    AudioUnitSetParameter(effectUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 100, 0);
//    AudioUnitSetParameter(effectUnit, kReverb2Param_Gain, kAudioUnitScope_Global, 0, 20, 0);
//    AudioUnitSetParameter(effectUnit, kReverb2Param_MinDelayTime, kAudioUnitScope_Global, 0, 1, 0);
//    AudioUnitSetParameter(effectUnit, kReverb2Param_MaxDelayTime, kAudioUnitScope_Global, 0, 1, 0);
//    AudioUnitSetParameter(effectUnit, kReverb2Param_DecayTimeAt0Hz, kAudioUnitScope_Global, 0, 20, 0);
//    AudioUnitSetParameter(effectUnit, kReverb2Param_DecayTimeAtNyquist, kAudioUnitScope_Global, 0, 20, 0);
//    AudioUnitSetParameter(effectUnit, kReverb2Param_RandomizeReflections, kAudioUnitScope_Global, 0, 1000, 0);
    
//均衡器效果
//    // Global, dB, -96->24, 0
//    kAUNBandEQParam_GlobalGain                                = 0,
//
//    // Global, Boolean, 0 or 1, 1
//    kAUNBandEQParam_BypassBand                                = 1000,
//
//    // Global, Indexed, 0->kNumAUNBandEQFilterTypes-1, 0
//    kAUNBandEQParam_FilterType                                = 2000,
//
//    // Global, Hz, 20->(SampleRate/2), 1000
//    kAUNBandEQParam_Frequency                                = 3000,
//
//    // Global, dB, -96->24, 0
//    kAUNBandEQParam_Gain                                    = 4000,
//
//    // Global, octaves, 0.05->5.0, 0.5
//    kAUNBandEQParam_Bandwidth                                = 5000
    
    AudioUnitSetParameter(effectUnit,kAUNBandEQParam_FilterType,kAudioUnitScope_Global,0,kAUNBandEQFilterType_Parametric,0);
    AudioUnitSetParameter(effectUnit,kAUNBandEQParam_BypassBand,kAudioUnitScope_Global,0,1,0);
    AudioUnitSetParameter(effectUnit,kAUNBandEQParam_Frequency,kAudioUnitScope_Global,0,1000,0);
    AudioUnitSetParameter(effectUnit,kAUNBandEQParam_Gain,kAudioUnitScope_Global,0,0,0);
    AudioUnitSetParameter(effectUnit,kAUNBandEQParam_Bandwidth,kAudioUnitScope_Global,0,0.05,0);

    //压缩器
//
//    // Global, dB, -40->20, -20
//    kDynamicsProcessorParam_Threshold             = 0,
//
//    // Global, dB, 0.1->40.0, 5
//    kDynamicsProcessorParam_HeadRoom             = 1,
//
//    // Global, rate, 1->50.0, 2
//    kDynamicsProcessorParam_ExpansionRatio        = 2,
//
//    // Global, dB
//    kDynamicsProcessorParam_ExpansionThreshold    = 3,
//
//    // Global, secs, 0.0001->0.2, 0.001
//    kDynamicsProcessorParam_AttackTime             = 4,
//
//    // Global, secs, 0.01->3, 0.05
//    kDynamicsProcessorParam_ReleaseTime         = 5,
//
//    // Global, dB, -40->40, 0
//    kDynamicsProcessorParam_MasterGain             = 6,
//
//    // Global, dB, read-only parameter
//    kDynamicsProcessorParam_CompressionAmount     = 1000,
//    kDynamicsProcessorParam_InputAmplitude        = 2000,
//    kDynamicsProcessorParam_OutputAmplitude     = 3000
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_Threshold,kAudioUnitScope_Global,0,-20,0);
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_HeadRoom,kAudioUnitScope_Global,0,12,0);
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_ExpansionRatio,kAudioUnitScope_Global,0,1.3,0);
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_ExpansionThreshold,kAudioUnitScope_Global,0,-25,0);
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_AttackTime,kAudioUnitScope_Global,0,0.001,0);
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_ReleaseTime,kAudioUnitScope_Global,0,0.5,0);
//    AudioUnitSetParameter(effectUnit,kDynamicsProcessorParam_MasterGain,kAudioUnitScope_Global,0,1.8,0);


    AudioStreamBasicDescription ioFormat;
    UInt32 ioSize = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty(ioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &ioFormat, &ioSize);

    AudioStreamBasicDescription effectUnitFormat;
    UInt32 size = sizeof(AudioStreamBasicDescription);
    AudioUnitGetProperty(effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &effectUnitFormat, &size);

    
    status = AudioUnitSetProperty(effectUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Global, 0, &ioFormat, sizeof(AudioStreamBasicDescription));
    CheckStatus(status, @"设置音效输出格式失败", YES);
    
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
    status = AudioUnitSetProperty(effectUnit, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Global, 0, &effectInputCallbackStruct, sizeof(effectInputCallbackStruct));
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
    if (ioData->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [play stop];
        });
    }
    return noErr;
}

static OSStatus PlayCallback(void *inRefCon,AudioUnitRenderActionFlags *ioActionFlag,const AudioTimeStamp *inTimeStamp,UInt32 inBusNumber,UInt32 inNumberFrames,AudioBufferList *ioData){

    __unsafe_unretained LLYAudioUnitEffect *play = (__bridge LLYAudioUnitEffect *)inRefCon;

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


- (void)start{
    [self initAudioUnit];
}

- (void)stop{
    
    AudioOutputUnitStop(ioUnit);
    AudioOutputUnitStop(effectUnit);
    [inputStream close];
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
