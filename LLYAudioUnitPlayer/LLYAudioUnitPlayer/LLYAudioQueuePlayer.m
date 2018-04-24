//
//  LLYAudioQueuePlayer.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/16.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYAudioQueuePlayer.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import <pthread.h>

#define kNumberOfBuffers 3              //AudioQueueBuffer数量，一般指明为3
#define kAQBufSize 128 * 1024           //每个AudioQueueBuffer的大小
#define kAudioFileBufferSize 2048       //文件读取数据的缓冲区大小
#define kMaxPacketDesc 512              //最大的AudioStreamPacketDescription个数

@interface LLYAudioQueuePlayer (){
    
    AudioFileStreamID audioFileStreamID;//文件id
    AudioStreamBasicDescription asbd;//文件基本格式
    AudioQueueBufferRef audioQueueBuffer[kNumberOfBuffers];//buffer数组
    bool inuse[kNumberOfBuffers];//当前buffer使用标记
    AudioStreamPacketDescription audioStreamPacketDesc[kMaxPacketDesc];//保存音频帧的数组
    AudioQueueRef audioQueue;//audio queue实例
    
    NSLock *audioInUseLock;//线程锁
    
//    pthread_mutex_t mutex;            // a mutex to protect the inuse flags
//    pthread_cond_t cond;            // a condition varable for handling the inuse flags
//    pthread_cond_t done;            // a condition varable for handling the inuse flags
}

@property (nonatomic, strong) NSFileHandle *audioFileHandle;//文件处理实例句柄
@property (nonatomic, strong) NSData *audioFileData;//每次读取到的文件数据
@property (nonatomic, assign) NSInteger audioFileDataOffset;//音频数据在文件中的偏移量
@property (nonatomic, assign) NSInteger audioFileLength;//音频文件大小
@property (nonatomic, assign) NSInteger audioBitRate;
@property (nonatomic, assign) CGFloat audioDuration;
@property (nonatomic, assign,getter=isPlaying) bool playing;

@property (nonatomic, assign) NSInteger audioPacketsFilled;//当前buffer填充了多少帧
@property (nonatomic, assign) NSInteger audioDataBytesFilled;//当前buffer填充的数据大小
@property (nonatomic, assign) NSInteger audioBufferIndex;//当前填充的buffer序号

@end

@implementation LLYAudioQueuePlayer

- (instancetype)initWithAudioFilePath:(NSString *)audioFilePath{
    self = [super init];
    if (self) {
        self.audioFileHandle = [NSFileHandle fileHandleForReadingAtPath:audioFilePath];
        audioInUseLock = [[NSLock alloc]init];
//        pthread_mutex_init(&self->mutex, NULL);
//        pthread_cond_init(&self->cond, NULL);
//        pthread_cond_init(&self->done, NULL);
    }
    return self;
}

- (void)createQueue{
    
//    参数及返回说明如下：
//    1. inFormat：该参数指明了即将播放的音频的数据格式
//    2. inCallbackProc：该回调用于当AudioQueue已使用完一个缓冲区时通知用户，用户可以继续填充音频数据
//    3. inUserData：由用户传入的数据指针，用于传递给回调函数
//    4. inCallbackRunLoop：指明回调事件发生在哪个RunLoop之中，如果传递NULL，表示在AudioQueue所在的线程上执行该回调事件，一般情况下，传递NULL即可。
//    5. inCallbackRunLoopMode：指明回调事件发生的RunLoop的模式，传递NULL相当于kCFRunLoopCommonModes，通常情况下传递NULL即可
//    6. outAQ：该AudioQueue的引用实例，
    OSStatus status = AudioQueueNewOutput(&asbd, AudioQueueOutput_Callback, (__bridge void *)self, NULL, NULL, 0, &audioQueue);
    if (status == noErr) {
        for (int i = 0; i < kNumberOfBuffers; i++) {
            
//            该方法的作用是为存放音频数据的缓冲区开辟空间
//
//            参数及返回说明如下：
//            1. inAQ：AudioQueue的引用实例
//            2. inBufferByteSize：需要开辟的缓冲区的大小
//            3. outBuffer：开辟的缓冲区的引用实例
            
            AudioQueueAllocateBuffer(audioQueue, kAQBufSize, &audioQueueBuffer[i]);
        }
    }
}

//该回调用于当AudioQueue已使用完一个缓冲区时通知用户，用户可以继续填充音频数据
void AudioQueueOutput_Callback(void *inClientData,AudioQueueRef inAQ,AudioQueueBufferRef inBuffer){
    
    LLYAudioQueuePlayer *audioPlayer = (__bridge LLYAudioQueuePlayer *)inClientData;
    for (int i = 0; i < kNumberOfBuffers; i++) {
        if (inBuffer == audioPlayer->audioQueueBuffer[i]) {
//            pthread_mutex_lock(&audioPlayer->mutex);
//            audioPlayer->inuse[i] = false;
//            pthread_cond_signal(&audioPlayer->cond);
//            printf("MyAudioQueueOutputCallback->unlock\n");
//            pthread_mutex_unlock(&audioPlayer->mutex);
            
        }
    }
}


- (void)startPlay{
    
    if (audioFileStreamID == NULL) {
        
//        AudioFileStreamOpen的参数说明如下：
//        1. inClientData：用户指定的数据，用于传递给回调函数，这里我们指定(__bridge LocalAudioPlayer*)self
//        2. inPropertyListenerProc：当解析到一个音频信息时，将回调该方法
//        3. inPacketsProc：当解析到一个音频帧时，将回调该方法
//        4. inFileTypeHint：指明音频数据的格式，如果你不知道音频数据的格式，可以传0
//        5. outAudioFileStream：AudioFileStreamID实例，需保存供后续使用
        
        AudioFileStreamOpen((__bridge void *)self, AudioFileStreamPropertyListenerProc, AudioFileStreamPacketsProc, kAudioFileMP3Type, &audioFileStreamID);
    }
    do {
        self.audioFileData = [self.audioFileHandle readDataOfLength:kAudioFileBufferSize];
        
//        参数的说明如下：
//        1. inAudioFileStream：AudioFileStreamID实例，由AudioFileStreamOpen打开
//        2. inDataByteSize：此次解析的数据字节大小
//        3. inData：此次解析的数据大小
//        4. inFlags：数据解析标志，其中只有一个值kAudioFileStreamParseFlag_Discontinuity = 1，表示解析的数据是否是不连续的，目前我们可以传0。

        OSStatus error = AudioFileStreamParseBytes(audioFileStreamID, (UInt32)self.audioFileData.length, self.audioFileData.bytes, 0);
        if (error != noErr) {
            NSLog(@"AudioFileStreamParseBytes 失败");
        }
    } while (self.audioFileData != nil && self.audioFileData.length > 0);
    
    [self.audioFileHandle closeFile];
    
}

- (void)pause{
    if (audioQueue && self.isPlaying) {
        AudioQueuePause(audioQueue);
        self.playing = NO;
    }
}

- (void)stop{
    
    if (audioQueue && self.isPlaying) {
        AudioQueueStop(audioQueue,true);
        self.playing = NO;
    }
    AudioQueueReset(audioQueue);
}

//当解析到一个音频信息时，将回调该方法
void AudioFileStreamPropertyListenerProc(void *inClientData,
                                         AudioFileStreamID inAudioFileStream,
                                         AudioFileStreamPropertyID inPropertyID,
                                         UInt32 *ioFlags){
    LLYAudioQueuePlayer *audioPlayer = (__bridge LLYAudioQueuePlayer *)inClientData;
    
    switch (inPropertyID) {
            //该属性指明了音频数据的格式信息，返回的数据是一个AudioStreamBasicDescription结构
        case kAudioFileStreamProperty_DataFormat:{
            if (audioPlayer->asbd.mSampleRate == 0) {
                UInt32 ioPropertyDataSize = sizeof(audioPlayer->asbd);
                //获取音频数据格式
                 OSStatus error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataFormat, &ioPropertyDataSize, &audioPlayer->asbd);
                if (error != noErr) {
                    NSLog(@"获取音频数据格式 失败");
                    break;
                }
                [audioPlayer printAudioStreamBasicDescription:audioPlayer->asbd];
            }
        }
            break;
            
            //该属性告诉我们，已经解析到完整的音频帧数据，准备产生音频帧，之后会调用到另外一个回调函数，我们在这里创建音频队列AudioQueue，如果音频数据中有Magic Cookie Data，则先调用AudioFileStreamGetPropertyInfo，获取该数据是否可写，如果可写再取出该属性值，并写入到AudioQueue。之后便是音频数据帧的解析。
        case kAudioFileStreamProperty_ReadyToProducePackets:{
            
            OSStatus error = noErr;
            
            UInt32 packetsCount,ioPropertyDataSize = sizeof(packetsCount);
            error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_ReadyToProducePackets, &ioPropertyDataSize, &packetsCount);
            if (error != noErr) {
                NSLog(@"packetsCount error");
                break;
            }
            
            //创建audioqueue
            [audioPlayer createQueue];
            
            //get the cookie size
            UInt32 cookieSize;
            Boolean writeable;
            error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, &writeable);
            if (error != noErr) {
                NSLog(@"get cookieSize error");
                break;
            }
            
            //get the cookie data
            void *cookieData = calloc(1, cookieSize);
            error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_MagicCookieData, &cookieSize, cookieData);
            if (error != noErr) {
                NSLog(@"get cookieData error");
                break;
            }
            
            //set the cookie on the queue
            error = AudioQueueSetProperty(audioPlayer->audioQueue, kAudioQueueProperty_MagicCookie, cookieData, cookieSize);
            if (error != noErr) {
                NSLog(@"set cookieData error");
                break;
            }
            
            //listen for kAudioQueueProperty_IsRunning
            error = AudioQueueAddPropertyListener(audioPlayer->audioQueue, kAudioQueueProperty_IsRunning, MyAudioQueueIsRunningCallback, (__bridge void *)audioPlayer);
            if (error != noErr) {
                NSLog(@"audioqueue listen error");
                break;
            }
            
        }
            break;
            
            //该属性指明了音频数据的编码格式，如MPEG等
        case kAudioFileStreamProperty_FileFormat:{
            UInt32 fileFormat,ioPropertyDataSize = sizeof(fileFormat);
            OSStatus error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_FileFormat, &ioPropertyDataSize, &fileFormat);
            if (error != noErr) {
                NSLog(@"获取音频数据的编码格式失败");
                break;
            }
        }
            break;
            
//            该属性可获取到音频数据的长度，可用于计算音频时长，计算公式为：
//            时长 = (音频数据字节大小 * 8) / 采样率
        case kAudioFileStreamProperty_AudioDataByteCount:{
            UInt64 dataByteCount;
            UInt32 ioPropertyDataSize = sizeof(dataByteCount);
            OSStatus error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataByteCount, &ioPropertyDataSize, &dataByteCount);
            if(error != noErr){
                NSLog(@"kAudioFileStreamProperty_AudioDataByteCount 失败");
                break;
            }
            audioPlayer.audioFileLength += dataByteCount;
            
            if (dataByteCount != 0) {
                audioPlayer.audioDuration = (dataByteCount * 8)/audioPlayer.audioBitRate;
            }
        }
            break;
            
            //该属性指明了音频文件中共有多少帧
        case kAudioFileStreamProperty_AudioDataPacketCount:{
            UInt64 dataBytesCount;
            UInt32 ioPropertyDataSize = sizeof(dataBytesCount);
            OSStatus error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_AudioDataPacketCount, &ioPropertyDataSize, &dataBytesCount);
            if(error != noErr){
                NSLog(@"kAudioFileStreamProperty_AudioDataPacketCount 失败");
                break;
            }
        }
            break;
            
//            该属性指明了音频数据在整个音频文件中的偏移量：
//            音频文件总大小 = 偏移量 + 音频数据字节大小
        case kAudioFileStreamProperty_DataOffset:{
            SInt64 audioDataOffset;
            UInt32 ioPropertyDataSize = sizeof(audioDataOffset);
            
            OSStatus error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_DataOffset, &ioPropertyDataSize, &audioDataOffset);
            if(error != noErr){
                NSLog(@"kAudioFileStreamProperty_DataOffset 失败");
                break;
            }
            audioPlayer.audioFileDataOffset = audioDataOffset;
            
            if (audioPlayer.audioFileDataOffset != 0) {
                audioPlayer.audioFileLength += audioPlayer.audioFileDataOffset;
            }
        }
            break;
            
            //该属性可获取到音频的采样率，可用于计算音频时长
        case kAudioFileStreamProperty_BitRate:{
            UInt32 bitRate;
            UInt32 ioPropertyDataSize = sizeof(bitRate);
            
            OSStatus error = AudioFileStreamGetProperty(inAudioFileStream, kAudioFileStreamProperty_BitRate, &ioPropertyDataSize, &bitRate);
            
            if(error != noErr){
                NSLog(@"kAudioFileStreamProperty_BitRate 失败");
                break;
            }

            if (bitRate != 0) {
                audioPlayer.audioBitRate = bitRate;
            }
            
            if (audioPlayer.audioFileLength != 0) {
                audioPlayer.audioDuration = (audioPlayer.audioFileLength * 8)/audioPlayer.audioBitRate;
            }
        }
            break;
            
        default:
            break;
    }
}

//当解析到一个音频帧时，将回调该方法
void AudioFileStreamPacketsProc(void *inClientData,
                                UInt32 inNumberBytes,
                                UInt32 inNumberPackets,
                                const void *inInputData,
                                AudioStreamPacketDescription *inPacketDescriptions){
    
    LLYAudioQueuePlayer *audioPlayer = (__bridge LLYAudioQueuePlayer *)inClientData;
    for (int i = 0; i < inNumberPackets; i++) {
        SInt64 mStartOffset = inPacketDescriptions[i].mStartOffset;
        UInt32 mDataByteSize = inPacketDescriptions[i].mDataByteSize;
        
        //如果当前要填充的数据大于缓冲区剩余大小，将当前buffer送入播放队列，指示将当前帧放入到下一个buffer
        if (mDataByteSize > kAQBufSize - audioPlayer.audioDataBytesFilled) {
            
            OSStatus err = AudioQueueEnqueueBuffer(audioPlayer->audioQueue, audioPlayer->audioQueueBuffer[audioPlayer.audioBufferIndex], (UInt32)audioPlayer.audioDataBytesFilled, audioPlayer->audioStreamPacketDesc);
            if (err == noErr) {
                audioPlayer.audioBufferIndex = (++audioPlayer.audioBufferIndex) % kNumberOfBuffers;
                audioPlayer.audioPacketsFilled = 0;
                audioPlayer.audioDataBytesFilled = 0;
                
                
                if (!audioPlayer.isPlaying) {
                    err = AudioQueueStart(audioPlayer->audioQueue, NULL);
                    if (err != noErr) {
                        NSLog(@"play failed");
                        continue;
                    }
                    audioPlayer.playing = YES;
                }
                
                // wait until next buffer is not in use
//                pthread_mutex_lock(&audioPlayer->mutex);
//                while (audioPlayer->inuse[audioPlayer.audioBufferIndex]) {
//                    printf("... WAITING ...\n");
//                    pthread_cond_wait(&audioPlayer->cond, &audioPlayer->mutex);
//                }
//                pthread_mutex_unlock(&audioPlayer->mutex);
//                printf("WaitForFreeBuffer->unlock\n");
                
            }
        }
        
        AudioQueueBufferRef currentFillBuffer = audioPlayer->audioQueueBuffer[audioPlayer.audioBufferIndex];
        audioPlayer->inuse[audioPlayer.audioBufferIndex] = YES;
        currentFillBuffer->mAudioDataByteSize = (UInt32)audioPlayer.audioDataBytesFilled + mDataByteSize;
        memcpy(currentFillBuffer->mAudioData + audioPlayer.audioPacketsFilled, inInputData + mStartOffset, mDataByteSize);
        
        audioPlayer->audioStreamPacketDesc[audioPlayer.audioPacketsFilled] = inPacketDescriptions[i];
        audioPlayer->audioStreamPacketDesc[audioPlayer.audioPacketsFilled].mStartOffset = audioPlayer.audioDataBytesFilled;
        audioPlayer.audioDataBytesFilled += mDataByteSize;
        audioPlayer.audioPacketsFilled += 1;
    }
}


void MyAudioQueueIsRunningCallback(void *inClientData,AudioQueueRef inAQ,AudioQueuePropertyID inID){
    
    LLYAudioQueuePlayer *audioPlayer = (__bridge LLYAudioQueuePlayer *)inClientData;
    
    UInt32 running;
    UInt32 size;
    OSStatus err = AudioQueueGetProperty(inAQ, kAudioQueueProperty_IsRunning, &running, &size);
    if (err == noErr) {
        if (!running) {
            
//            printf("MyAudioQueueIsRunningCallback->lock\n");
//            pthread_mutex_lock(&audioPlayer->mutex);
//            pthread_cond_signal(&audioPlayer->done);
//            printf("MyAudioQueueIsRunningCallback->unlock\n");
//            pthread_mutex_unlock(&audioPlayer->mutex);
//
            AudioQueueReset(audioPlayer->audioQueue);
            for (int i = 0; i < kNumberOfBuffers; i++) {
                AudioQueueFreeBuffer(audioPlayer->audioQueue, audioPlayer->audioQueueBuffer[i]);
            }
            
            AudioQueueDispose(audioPlayer->audioQueue, true);
            audioPlayer->audioQueue = NULL;
            
            AudioFileStreamClose(audioPlayer->audioFileStreamID);
            
        }
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
