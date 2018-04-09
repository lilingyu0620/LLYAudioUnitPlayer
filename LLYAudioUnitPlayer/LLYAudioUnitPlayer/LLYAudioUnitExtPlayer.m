//
//  LLYAudioUnitExtPlayer.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/9.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioUnitExtPlayer.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

#define OUTPUT_BUS (0)

const uint32_t BUFFER_SIZE_CONST = 0x10000;

@implementation LLYAudioUnitExtPlayer{
    
    ExtAudioFileRef extAudioFile;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamBasicDescription outputFormat;
    
    SInt32 readedFrame;
    UInt64 totalFrame;
    
    AudioUnit extAudioUnit;
    AudioBufferList *bufferList;
}

- (void)initExtAudioUnit{
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil]; // 只有播放
    
    // BUFFER
    bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = BUFFER_SIZE_CONST;
    bufferList->mBuffers[0].mData = malloc(BUFFER_SIZE_CONST);
    
    OSStatus status = noErr;
    NSURL *mp3Url = [NSURL fileURLWithPath:[CommonUtil bundlePath:@"/abc.mp3"]];
    status = ExtAudioFileOpenURL((__bridge CFURLRef)mp3Url, &extAudioFile);
    if (status) {
        NSLog(@"打开文件失败");
    }
    
    uint32_t size = sizeof(AudioStreamBasicDescription);
    status = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileDataFormat, &size, &audioFileFormat);
    if (status) {
        NSLog(@"读取音频格式失败");
    }
    NSLog(@"audiofile format:");
    [self printAudioStreamBasicDescription:audioFileFormat];
    
    
    //initFormat
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mBytesPerPacket   = 2;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = 2;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel   = 16;
    
    NSLog(@"output format:");
    [self printAudioStreamBasicDescription:outputFormat];
    
    status = ExtAudioFileSetProperty(extAudioFile, kExtAudioFileProperty_ClientDataFormat, size, &outputFormat);
    if (status) {
        NSLog(@"设置转码音频格式失败");
    }
    
    size = sizeof(totalFrame);
    status = ExtAudioFileGetProperty(extAudioFile, kExtAudioFileProperty_FileLengthFrames, &size, &totalFrame);
    if (status) {
        NSLog(@"获取音频总长度失败");
    }
    NSLog(@"音频总长度：%llu",totalFrame);
    
    readedFrame = 0;
    
    //设置AudioUnit相关属性
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &extAudioUnit);
    if (status) {
        NSLog(@"创建compenent失败");
    }
    
    status = AudioUnitSetProperty(extAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"设置format失败");
    }
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = ExtPlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(extAudioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &playCallback,
                                  sizeof(playCallback));
    if (status) {
        NSLog(@"设置回调失败");
    }
    
    status = AudioUnitInitialize(extAudioUnit);
    if (status) {
        NSLog(@"初始化AudioUint失败");
    }
}

OSStatus ExtPlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    LLYAudioUnitExtPlayer *player = (__bridge LLYAudioUnitExtPlayer *)inRefCon;
    player->bufferList->mBuffers[0].mDataByteSize = BUFFER_SIZE_CONST;
    OSStatus status = ExtAudioFileRead(player->extAudioFile, &inNumberFrames, player->bufferList);
    NSLog(@"inNumberFrames = %d",inNumberFrames);
    if (status) {
        NSLog(@"转码失败");
    }
    if (!inNumberFrames) {
        NSLog(@"播放结束");
    }
    NSLog(@"out size : %d",player->bufferList->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, player->bufferList->mBuffers[0].mData, player->bufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = player->bufferList->mBuffers[0].mDataByteSize;
    
    player->readedFrame += player->bufferList->mBuffers[0].mDataByteSize / player->outputFormat.mBytesPerFrame;
    
    NSLog(@"readedFrame = %d",player->readedFrame);
    
    if (player->bufferList->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player onPlayEnd];
        });
    }
    return noErr;
}


- (void)play{
    [self initExtAudioUnit];
    AudioOutputUnitStart(extAudioUnit);
}

- (void)onPlayEnd {
    AudioOutputUnitStop(extAudioUnit);
    AudioUnitUninitialize(extAudioUnit);
    AudioComponentInstanceDispose(extAudioUnit);
    
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        
        free(bufferList);
        bufferList = NULL;
    }
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
