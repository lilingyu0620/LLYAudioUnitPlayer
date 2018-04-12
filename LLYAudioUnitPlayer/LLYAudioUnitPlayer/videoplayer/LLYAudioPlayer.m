//
//  LLYAudioPlayer.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/11.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioPlayer.h"

const uint32_t XXX_CONST_BUFFER_SIZE = 0x10000;

@implementation LLYAudioPlayer{
    
    AudioUnit ioUnit;
    AudioBufferList *bufferList;
    UInt32 readerSize;
}

- (void)initAudioUnitWithOutputASBD:(AudioStreamBasicDescription)outputFormat{
    
    [self printAudioStreamBasicDescription:outputFormat];
    
    NSError *error = nil;
    OSStatus status = noErr;
    
    [[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error];
    [[AVAudioSession sharedInstance] setPreferredIOBufferDuration:0.1 error:&error];
    
    AudioComponentDescription audioDesc;
    audioDesc.componentType = kAudioUnitType_Output;
    audioDesc.componentSubType = kAudioUnitSubType_RemoteIO;
    audioDesc.componentManufacturer = kAudioUnitManufacturer_Apple;
    audioDesc.componentFlags = 0;
    audioDesc.componentFlagsMask = 0;
    
    AudioComponent inputComponent = AudioComponentFindNext(NULL, &audioDesc);
    AudioComponentInstanceNew(inputComponent, &ioUnit);
    
    status = AudioUnitSetProperty(ioUnit,
                                  kAudioUnitProperty_StreamFormat,
                                  kAudioUnitScope_Input,
                                  0,
                                  &outputFormat,
                                  sizeof(outputFormat));
    if (status) {
        NSLog(@"set stream status %d", (int)status);
    }
    
    // callback
    AURenderCallbackStruct playCallback;
    playCallback.inputProc = PlayCallback;
    playCallback.inputProcRefCon = (__bridge void *)self;
    AudioUnitSetProperty(ioUnit,
                         kAudioUnitProperty_SetRenderCallback,
                         kAudioUnitScope_Input,
                         0,
                         &playCallback,
                         sizeof(playCallback));
    
    
    status = AudioUnitInitialize(ioUnit);
    if (status) {
        NSLog(@"init status %d", (int)status);
    }
    
}


static OSStatus PlayCallback(void *inRefCon,
                             AudioUnitRenderActionFlags *ioActionFlags,
                             const AudioTimeStamp *inTimeStamp,
                             UInt32 inBusNumber,
                             UInt32 inNumberFrames,
                             AudioBufferList *ioData){
    LLYAudioPlayer *player = (__bridge LLYAudioPlayer *)inRefCon;
    if (!player->bufferList ||  player->readerSize + ioData->mBuffers[0].mDataByteSize > player->bufferList->mBuffers[0].mDataByteSize) {
        if ([player.delegate respondsToSelector:@selector(audioData)]) {
            player->bufferList = [player->_delegate audioData];
            player->readerSize = 0;
        }
    }
    
    if (!player->bufferList || player->bufferList->mNumberBuffers == 0) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [player stop];
        });
    }
    else {
        for (int i = 0; i < player->bufferList->mNumberBuffers; ++i) {
            memcpy(ioData->mBuffers[i].mData, player->bufferList->mBuffers[i].mData + player->readerSize, ioData->mBuffers[i].mDataByteSize);
            player->readerSize += ioData->mBuffers[i].mDataByteSize;
        }
    }
    
    return noErr;
}

- (void)play{
    AudioOutputUnitStart(ioUnit);
}

- (void)stop{
    AudioOutputUnitStop(ioUnit);
    if ([self.delegate respondsToSelector:@selector(onPlayToEnd:)]) {
        [self.delegate onPlayToEnd:self];
    }
}

- (void)dealloc{
    AudioUnitUninitialize(ioUnit);
    AudioComponentInstanceDispose(ioUnit);
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
