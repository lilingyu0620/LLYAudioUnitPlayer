//
//  LLYVideoPlayerViewController.m
//  LLYAudioUnitPlayer
//
//  Created by lly on 2018/4/11.
//  Copyright © 2018年 lly. All rights reserved.
//

#import "LLYVideoPlayerViewController.h"
#import "LYOpenGLView.h"
#import "LLYAudioPlayer.h"

@interface LLYVideoPlayerViewController ()<LLYAudioPlayerDelegate>

@property (nonatomic , strong) AVAsset *mAsset;
@property (nonatomic , strong) AVAssetReader *mReader;
@property (nonatomic, assign) CMBlockBufferRef blockBufferOut;
@property (nonatomic, assign) AudioBufferList audioBufferList;


@property (weak, nonatomic) IBOutlet LYOpenGLView *glView;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderVideoTrackOutput;
@property (nonatomic , strong) CADisplayLink *mDisplayLink;

@property (nonatomic, strong) LLYAudioPlayer *audioPlayer;
@property (nonatomic , strong) AVAssetReaderTrackOutput *mReaderAudioTrackOutput;
@property (nonatomic , assign) AudioStreamBasicDescription fileFormat;

@end

@implementation LLYVideoPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self loadAsset];
    
    self.audioPlayer = [[LLYAudioPlayer alloc]init];
    self.audioPlayer.delegate = self;
}

- (void)loadAsset {
    NSDictionary *inputOptions = [NSDictionary dictionaryWithObject:[NSNumber numberWithBool:YES] forKey:AVURLAssetPreferPreciseDurationAndTimingKey];
    AVURLAsset *inputAsset = [[AVURLAsset alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"abc" withExtension:@"mp4"] options:inputOptions];
    __weak typeof(self) weakSelf = self;
    [inputAsset loadValuesAsynchronouslyForKeys:[NSArray arrayWithObject:@"tracks"] completionHandler: ^{
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [inputAsset statusOfValueForKey:@"tracks" error:&error];
            if (tracksStatus != AVKeyValueStatusLoaded)
            {
                NSLog(@"error %@", error);
                return;
            }
            weakSelf.mAsset = inputAsset;
        });
    }];
}

- (AVAssetReader*)createAssetReader
{
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.mAsset error:&error];
    
    NSMutableDictionary *outputSettings = [NSMutableDictionary dictionary];
    [outputSettings setObject:@(kAudioFormatLinearPCM) forKey:AVFormatIDKey];
    [outputSettings setObject:@(16) forKey:AVLinearPCMBitDepthKey];
    [outputSettings setObject:@(NO) forKey:AVLinearPCMIsBigEndianKey];
    [outputSettings setObject:@(NO) forKey:AVLinearPCMIsFloatKey];
    [outputSettings setObject:@(YES) forKey:AVLinearPCMIsNonInterleaved];
    [outputSettings setObject:@(44100.0) forKey:AVSampleRateKey];
    [outputSettings setObject:@(1) forKey:AVNumberOfChannelsKey];
    
    AudioStreamBasicDescription inputFormat;
    inputFormat.mSampleRate = 44100;
    inputFormat.mFormatID = kAudioFormatLinearPCM;
    inputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsNonInterleaved;
    inputFormat.mFramesPerPacket = 1;
    inputFormat.mChannelsPerFrame = 1;
    inputFormat.mBytesPerPacket = 2;
    inputFormat.mBytesPerFrame = 2;
    inputFormat.mBitsPerChannel = 16;
    self.fileFormat = inputFormat;
    
    NSArray<AVAssetTrack *>* audioTracks = [self.mAsset tracksWithMediaType:AVMediaTypeAudio];
    self.mReaderAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTracks[0] outputSettings:outputSettings];
    self.mReaderAudioTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:self.mReaderAudioTrackOutput];
    
    NSArray *formatDesc = audioTracks[0].formatDescriptions;
    for(unsigned int i = 0; i < [formatDesc count]; ++i) {
        CMAudioFormatDescriptionRef item = (__bridge_retained CMAudioFormatDescriptionRef)[formatDesc objectAtIndex:i];
        const AudioStreamBasicDescription* fmtDesc = CMAudioFormatDescriptionGetStreamBasicDescription(item);
        if(fmtDesc ) {
            [self printAudioStreamBasicDescription:*fmtDesc];
        }
        CFRelease(item);
    }
    
    outputSettings = [NSMutableDictionary dictionary];
    [outputSettings setObject:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange) forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    self.mReaderVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:[[self.mAsset tracksWithMediaType:AVMediaTypeVideo] objectAtIndex:0] outputSettings:outputSettings];
    self.mReaderVideoTrackOutput.alwaysCopiesSampleData = NO;
    [assetReader addOutput:self.mReaderVideoTrackOutput];
    
    return assetReader;
}


- (IBAction)backBtnClicked:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)playBtnClicked:(id)sender {

    self.mReader = [self createAssetReader];
    [self.audioPlayer initAudioUnitWithOutputASBD:self.fileFormat];

    if ([self.mReader startReading] == NO)
    {
        NSLog(@"Error reading from file at URL: %@", self.mAsset);
        return;
    }
    else {
        NSLog(@"Start reading success.");
        [self.audioPlayer play];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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

#pragma mark - delegate

- (AudioBufferList *)audioData{
    CMSampleBufferRef sampleBuffer = [self.mReaderAudioTrackOutput copyNextSampleBuffer];
    size_t bufferListSizeNeededOut = 0;
    if (self.blockBufferOut != NULL) {
        CFRelease(self.blockBufferOut);
        self.blockBufferOut = NULL;
    }
    if (!sampleBuffer) {
        return NULL;
    }
    OSStatus err = CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer,
                                                                           &bufferListSizeNeededOut,
                                                                           &_audioBufferList,
                                                                           sizeof(self.audioBufferList),
                                                                           kCFAllocatorSystemDefault,
                                                                           kCFAllocatorSystemDefault,
                                                                           kCMSampleBufferFlag_AudioBufferList_Assure16ByteAlignment,
                                                                           &_blockBufferOut);
    if (err) {
        NSLog(@"CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer error: %d", (int)err);
    }
    
    CMTime presentationTimeStamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    int timeStamp = (1000 * (int)presentationTimeStamp.value) / presentationTimeStamp.timescale;
    NSLog(@"audio timestamp %d", timeStamp);
    
    CFRelease(sampleBuffer);
    
    return &_audioBufferList;
}


/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
