//
//  LLYAudioUnitRecord.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/7.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioUnitRecord.h"
#import <AudioUnit/AudioUnit.h>
#import <AVFoundation/AVFoundation.h>
#import "CommonUtil.h"

#define INPUT_BUS 1
#define OUTPUT_BUS 0

const uint32_t BUFFERSIZE = 0x10000;

@implementation LLYAudioUnitRecord{
    AudioUnit recordAudioUnit;
    AudioBufferList *bufferList;
    NSInputStream *inputStream;
    Byte *buffer;
}

- (void)start{
    
    [self initRecordAudioUnit];
    AudioOutputUnitStart(recordAudioUnit);
}
- (void)stop{
    
    AudioOutputUnitStop(recordAudioUnit);
    AudioUnitUninitialize(recordAudioUnit);
    
    if (bufferList != NULL) {
        if (bufferList->mBuffers[0].mData) {
            free(bufferList->mBuffers[0].mData);
            bufferList->mBuffers[0].mData = NULL;
        }
        free(bufferList);
        bufferList = NULL;
    }
    
    [inputStream close];
    AudioComponentInstanceDispose(recordAudioUnit);

    
}
- (void)initRecordAudioUnit{
    
    NSURL *url = [[NSBundle mainBundle]URLForResource:@"test" withExtension:@"pcm"];
    inputStream = [NSInputStream inputStreamWithURL:url];
    if (!inputStream) {
        NSLog(@"伴奏文件打开失败%@",url);
    }else{
        [inputStream open];
    }
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    //设置AVAudioSession
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if (error) {
        NSLog(@"setCategory error %@",error);
    }
    
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.05 error:&error];
    if (error) {
        NSLog(@"setPreferredIOBufferDuration error:%@", error);
    }
    
    // buffer list
    uint32_t numberBuffers = 2;
    bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) + (numberBuffers - 1) * sizeof(AudioBuffer));
    bufferList->mNumberBuffers = numberBuffers;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mDataByteSize = BUFFERSIZE;
    bufferList->mBuffers[0].mData = malloc(BUFFERSIZE);
    
    for (int i =1; i < numberBuffers; ++i) {
        bufferList->mBuffers[i].mNumberChannels = 1;
        bufferList->mBuffers[i].mDataByteSize = BUFFERSIZE;
        bufferList->mBuffers[i].mData = malloc(BUFFERSIZE);
    }
    
    buffer = malloc(BUFFERSIZE);
    
    // audio unit new
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    status = AudioComponentInstanceNew(inputComponent, &recordAudioUnit);
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    // set format
    AudioStreamBasicDescription inputFormat;
    inputFormat.mSampleRate = 44100;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mChannelsPerFrame = 1;
    inputFormat.mBytesPerPacket = 2;
    inputFormat.mBytesPerFrame = 2;
    inputFormat.mBitsPerChannel = 16;
    status = AudioUnitSetProperty(recordAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &inputFormat,
                                  sizeof(inputFormat));
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    AudioStreamBasicDescription outputFormat = inputFormat;
    outputFormat.mChannelsPerFrame = 2;
    status = AudioUnitSetProperty(recordAudioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &outputFormat,
                                  sizeof(outputFormat));
    
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    // enable record
    UInt32 flag = 1;
    status = AudioUnitSetProperty(recordAudioUnit,
                                  kAudioOutputUnitProperty_EnableIO,
                                  kAudioUnitScope_Input,
                                  INPUT_BUS,
                                  &flag,
                                  sizeof(flag));
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    
    // set callback
    AURenderCallbackStruct recordCallback;
    recordCallback.inputProc = RecordCallback;
    recordCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(recordAudioUnit,
                                  kAudioOutputUnitProperty_SetInputCallback,
                                  kAudioUnitScope_Output,
                                  INPUT_BUS,
                                  &recordCallback,
                                  sizeof(recordCallback));
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = OutPlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    status = AudioUnitSetProperty(recordAudioUnit,
                                  kAudioUnitProperty_SetRenderCallback,
                                  kAudioUnitScope_Input,
                                  OUTPUT_BUS,
                                  &playCallback,
                                  sizeof(playCallback));
    if (status != noErr) {
        NSLog(@"AudioUnitGetProperty error, ret: %d", status);
    }
    
    OSStatus result = AudioUnitInitialize(recordAudioUnit);
    NSLog(@"result %d", result);
}

#pragma mark - callback

static OSStatus RecordCallback(void *inRefCon,
                               AudioUnitRenderActionFlags *ioActionFlags,
                               const AudioTimeStamp *inTimeStamp,
                               UInt32 inBusNumber,
                               UInt32 inNumberFrames,
                               AudioBufferList *ioData)
{
    LLYAudioUnitRecord *record = (__bridge LLYAudioUnitRecord *)inRefCon;
    record->bufferList->mNumberBuffers = 1;
    OSStatus status = AudioUnitRender(record->recordAudioUnit, ioActionFlags, inTimeStamp, inBusNumber, inNumberFrames, record->bufferList);
    if (status != noErr) {
        NSLog(@"AudioUnitRender error:%d", status);
    }
    
    NSLog(@"size1 = %d", record->bufferList->mBuffers[0].mDataByteSize);
    [record writePCMData:record->bufferList->mBuffers[0].mData size:record->bufferList->mBuffers[0].mDataByteSize];
    
    return noErr;
}

static OSStatus OutPlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData) {
    LLYAudioUnitRecord *record = (__bridge LLYAudioUnitRecord *)inRefCon;
    memcpy(ioData->mBuffers[0].mData, record->bufferList->mBuffers[0].mData, record->bufferList->mBuffers[0].mDataByteSize);
    ioData->mBuffers[0].mDataByteSize = record->bufferList->mBuffers[0].mDataByteSize;
    
    NSInteger bytes = BUFFERSIZE < ioData->mBuffers[1].mDataByteSize * 2 ? BUFFERSIZE : ioData->mBuffers[1].mDataByteSize * 2; //
    bytes = [record->inputStream read:record->buffer maxLength:bytes];
    
    for (int i = 0; i < bytes; ++i) {
        ((Byte*)ioData->mBuffers[1].mData)[i/2] = record->buffer[i];
    }
    ioData->mBuffers[1].mDataByteSize = (UInt32)bytes / 2;
    
    if (ioData->mBuffers[1].mDataByteSize < ioData->mBuffers[0].mDataByteSize) {
        ioData->mBuffers[0].mDataByteSize = ioData->mBuffers[1].mDataByteSize;
    }
    
    
    NSLog(@"size2 = %d", ioData->mBuffers[0].mDataByteSize);
    
    return noErr;
}

- (void)writePCMData:(Byte *)buffer size:(int)size {
    static FILE *file = NULL;
    NSString *pathStr = [LLYAudioUnitRecord recordPath];
    if (!file) {
        file = fopen(pathStr.UTF8String, "w");
    }
    fwrite(buffer, size, 1, file);
}

+ (NSString *)recordPath{
    return [CommonUtil documentsPath:@"/record.pcm"];
}

@end
