//
//  LLYAudioUnitConverter.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/8.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioUnitConverter.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

#define INPUT_BUS (1)
#define OUTPUT_BUS (0)
#define NO_MORE_DATA (-12306)

const uint32_t CONST_BUFFER_SIZE = 0x10000;

@implementation LLYAudioUnitConverter{
    
    AudioFileID audioFileID;
    AudioStreamBasicDescription audioFileFormat;
    AudioStreamPacketDescription *audioPacketFormat;
    
    SInt64 readedPacket;
    UInt64 packetNums;
    UInt64 packetNumsInBuffer;
    
    AudioUnit audioUnit;
    AudioBufferList *bufferList;
    Byte *convertBuffer;
    
    AudioConverterRef audioConverter;
}

- (void)initConverter{
    
    //获取源音频的ID
    NSString *mp3Path = [CommonUtil bundlePath:@"abc.mp3"];
    NSURL *mp3Url = [NSURL fileURLWithPath:mp3Path];
    OSStatus status = AudioFileOpenURL((__bridge CFURLRef)mp3Url, kAudioFileReadPermission, 0, &audioFileID);
    if (status) {
        NSLog(@"打开文件失败 %@", mp3Url);
        return ;
    }
    
    //获取源音频的FileFormat
    uint32_t size = sizeof(AudioStreamBasicDescription);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyDataFormat, &size, &audioFileFormat);
    if (status) {
        NSLog(@"获取fileformat失败 error status %d", status);
        return ;
    }
    
    //获取源音频的packetnum
    size = sizeof(packetNums);
    status = AudioFileGetProperty(audioFileID, kAudioFilePropertyAudioDataPacketCount, &size, &packetNums);
    if (status) {
        NSLog(@"获取packetnum失败 error status %d", status);
        return ;
    }

    //获取源音频单个packet的最大buffer数
    uint32_t sizePerPacket = audioFileFormat.mFramesPerPacket;
    if (sizePerPacket == 0) {
        size = sizeof(sizePerPacket);
        status = AudioFileGetProperty(audioFileID, kAudioFilePropertyMaximumPacketSize, &size, &sizePerPacket);
        if (status) {
            NSLog(@"获取packetmaxnum失败 error status %d", status);
            return ;
        }
    }
    
    //获取源音频的packetformat
    audioPacketFormat = malloc(sizeof(AudioStreamPacketDescription) * (CONST_BUFFER_SIZE/sizePerPacket + 1));

    //初始化
    audioConverter = NULL;
    readedPacket = 0;
    NSError *error = nil;
    UInt32 flag = 1;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
    
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &audioUnit);
    
    // BUFFER
    bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList));
    bufferList->mNumberBuffers = 1;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    bufferList->mBuffers[0].mData = malloc(CONST_BUFFER_SIZE);
    
    convertBuffer = malloc(CONST_BUFFER_SIZE);
    
    //initAudioProperty
    flag = 1;
    if (flag) {
        status = AudioUnitSetProperty(audioUnit,
                                      kAudioOutputUnitProperty_EnableIO,
                                      kAudioUnitScope_Output,
                                      OUTPUT_BUS,
                                      &flag,
                                      sizeof(flag));
        if (status) {
            NSLog(@"AudioUnitSetProperty error with status:%d", status);
        }
    }
    
    //initFormat
    AudioStreamBasicDescription outputFormat;
    memset(&outputFormat, 0, sizeof(outputFormat));
    outputFormat.mSampleRate       = 44100;
    outputFormat.mFormatID         = kAudioFormatLinearPCM;
    outputFormat.mFormatFlags      = kLinearPCMFormatFlagIsSignedInteger;
    outputFormat.mBytesPerPacket   = 2;
    outputFormat.mFramesPerPacket  = 1;
    outputFormat.mBytesPerFrame    = 2;
    outputFormat.mChannelsPerFrame = 1;
    outputFormat.mBitsPerChannel   = 16;
    
    [self printAudioStreamBasicDescription:audioFileFormat];
    [self printAudioStreamBasicDescription:outputFormat];
    
    //初始化audioconverter
    status = AudioConverterNew(&audioFileFormat, &outputFormat, &audioConverter);
    if (status) {
        NSLog(@"AudioConverterNew eror with status:%d", status);
    }
    
    //设置输出格式
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"AudioUnitSetProperty eror with status:%d", status);
    }
    
    //设置回调
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = ConPlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(audioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &playCallback,
                                  sizeof(playCallback));
    if (status) {
        NSLog(@"AudioUnitSetProperty eror with status:%d", status);
    }
    
    
    OSStatus result = AudioUnitInitialize(audioUnit);
    NSLog(@"result %d", result);
    
}

OSStatus InputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    LLYAudioUnitConverter *player = (__bridge LLYAudioUnitConverter *)(inUserData);
    
    UInt32 byteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioFileReadPacketData(player->audioFileID, NO, &byteSize, player->audioPacketFormat, player->readedPacket, ioNumberDataPackets, player->convertBuffer);
    
    if (outDataPacketDescription) { // 这里要设置好packetFormat，否则会转码失败
        *outDataPacketDescription = player->audioPacketFormat;
    }
    
    if(status) {
        NSLog(@"读取文件失败");
    }
    
    if (!status && ioNumberDataPackets > 0) {
        ioData->mBuffers[0].mDataByteSize = byteSize;
        ioData->mBuffers[0].mData = player->convertBuffer;
        player->readedPacket += *ioNumberDataPackets;
        return noErr;
    }
    else {
        return NO_MORE_DATA;
    }
}

OSStatus ConPlayCallback(void *inRefCon,
                      AudioUnitRenderActionFlags *ioActionFlags,
                      const AudioTimeStamp *inTimeStamp,
                      UInt32 inBusNumber,
                      UInt32 inNumberFrames,
                      AudioBufferList *ioData) {
    LLYAudioUnitConverter *converter = (__bridge LLYAudioUnitConverter *)inRefCon;
    
    converter->bufferList->mBuffers[0].mDataByteSize = CONST_BUFFER_SIZE;
    OSStatus status = AudioConverterFillComplexBuffer(converter->audioConverter, InputDataProc, inRefCon, &inNumberFrames, converter->bufferList, NULL);
    if (status) {
        NSLog(@"转换格式失败 %d", status);
    }
    
    NSLog(@"out size: %d", converter->bufferList->mBuffers[0].mDataByteSize);
    memcpy(ioData->mBuffers[0].mData, converter->bufferList->mBuffers[0].mData, converter->bufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = converter->bufferList->mBuffers[0].mDataByteSize;
    
    //    fwrite(player->buffList->mBuffers[0].mData, player->buffList->mBuffers[0].mDataByteSize, 1, [player pcmFile]);
    
    if (converter->bufferList->mBuffers[0].mDataByteSize <= 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [converter onPlayEnd];
        });
    }
    return noErr;
}

- (void)play{
    [self initConverter];
    AudioOutputUnitStart(audioUnit);
}

- (void)onPlayEnd {
    AudioOutputUnitStop(audioUnit);
    AudioUnitUninitialize(audioUnit);
    AudioComponentInstanceDispose(audioUnit);
    
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        
        free(bufferList);
        bufferList = NULL;
    }
    if (convertBuffer != NULL) {
        free(convertBuffer);
        convertBuffer = NULL;
    }
    AudioConverterDispose(audioConverter);
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
