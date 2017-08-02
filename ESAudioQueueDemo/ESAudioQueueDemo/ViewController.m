//
//  ViewController.m
//  ESAudioQueueDemo
//
//  Created by xiangmingsheng on 2017/7/11.
//  Copyright © 2017年 XMSECODE. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>

static const int kNumberBuffers = 3;

typedef struct AQPlayerState {
    AudioStreamBasicDescription   mDataFormat;
    AudioQueueRef                 mQueue;
    AudioQueueBufferRef           mBuffers[kNumberBuffers];
    AudioFileID                   mAudioFile;
    UInt32                        bufferByteSize;
    SInt64                        mCurrentPacket;
    UInt32                        mNumPacketsToRead;
    AudioStreamPacketDescription  *mPacketDescs;
    bool                          mIsRunning;
}AQPlayerState;

@interface ViewController ()

@property (nonatomic, strong) NSThread *playThread;

@property(nonatomic,assign)AQPlayerState *playerState;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    

}

#pragma mark - Action
- (IBAction)didClickStartButton:(id)sender {
    
    if (self.playThread == nil || self.playerState->mIsRunning == false) {
        self.playThread = [[NSThread alloc] initWithTarget:self selector:@selector(playMusic) object:nil];
        
        [self.playThread start];
    }else {
        AudioQueueStart(self.playerState->mQueue, NULL);
    }
}

- (IBAction)didClickPauseButton:(id)sender {
    AudioQueuePause(self.playerState->mQueue);
}

- (IBAction)didClickStopButton:(id)sender {
    AudioQueueStop(self.playerState->mQueue, true);
    self.playThread = nil;
}

- (void)playMusic {
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:@"G.E.M.邓紫棋 - 喜欢你.mp3" ofType:nil];
    [self initAudioQueue:musicPath];
}


//The Playback Audio Queue Callback
static void HandleOutputBuffer(void* aqData,AudioQueueRef inAQ,AudioQueueBufferRef inBuffer){
    AQPlayerState *pAqData = (AQPlayerState *) aqData;
    //    if (pAqData->mIsRunning == 0) return; // 注意苹果官方文档这里有这一句,应该是有问题,这里应该是判断如果pAqData->isDone??
//    NSLog(@"回调");
    UInt32 numBytesReadFromFile = 4096;
    UInt32 numPackets = pAqData->mNumPacketsToRead;
//    AudioFileReadPackets(pAqData->mAudioFile,false,&numBytesReadFromFile,pAqData->mPacketDescs,pAqData->mCurrentPacket,&numPackets,inBuffer->mAudioData);
    AudioFileReadPacketData(pAqData->mAudioFile, false, &numBytesReadFromFile, pAqData->mPacketDescs, pAqData->mCurrentPacket, &numPackets, inBuffer->mAudioData);
    
    if (numPackets > 0) {
//        NSLog(@"播放==%zd",numBytesReadFromFile);
        
        inBuffer->mAudioDataByteSize = numBytesReadFromFile;
        AudioQueueEnqueueBuffer(inAQ,inBuffer,(pAqData->mPacketDescs ? numPackets : 0),pAqData->mPacketDescs);
        pAqData->mCurrentPacket += numPackets;
    } else {
        NSLog(@"numPackets <= 0");
        if (pAqData->mIsRunning) {
            
        }
        AudioQueueStop(inAQ,false);
        pAqData->mIsRunning = false;
    }
}

void DeriveBufferSize (AudioStreamBasicDescription inDesc,UInt32 maxPacketSize,Float64 inSeconds,UInt32 *outBufferSize,UInt32 *outNumPacketsToRead) {
    
    static const int maxBufferSize = 0x10000;
    static const int minBufferSize = 0x4000;
    
    if (inDesc.mFramesPerPacket != 0) {
        Float64 numPacketsForTime = inDesc.mSampleRate / inDesc.mFramesPerPacket * inSeconds;
        *outBufferSize = numPacketsForTime * maxPacketSize;
    } else {
        *outBufferSize = maxBufferSize > maxPacketSize ? maxBufferSize : maxPacketSize;
    }
    
    if (*outBufferSize > maxBufferSize && *outBufferSize > maxPacketSize){
        *outBufferSize = maxBufferSize;
    }
    else {
        if (*outBufferSize < minBufferSize){
            *outBufferSize = minBufferSize;
        }
    }
    
    *outNumPacketsToRead = *outBufferSize / maxPacketSize;
}

- (void)initAudioQueue:(NSString *)localFilePath {
    
    AQPlayerState aqData;
    self.playerState = &aqData;
    
    CFStringRef cfFilePath = (__bridge CFStringRef)localFilePath;
    //创建url
    CFURLRef cfURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault,cfFilePath , kCFURLPOSIXPathStyle, false);
    //打开文件
    int error = AudioFileOpenURL(cfURL, kAudioFileReadPermission, 0, &aqData.mAudioFile);
    if ([self checkError:error] == NO) {
        return;
    }else {
        NSLog(@"打开文件成功");
    }
    //释放url
    CFRelease(cfURL);
    //计算结构体数据大小
    UInt32 dateFormatSize = sizeof(aqData.mDataFormat);
    NSLog(@"dateFormatSize == %zd",dateFormatSize);
    //获取格式
    error = AudioFileGetProperty(aqData.mAudioFile, kAudioFilePropertyDataFormat, &dateFormatSize, &aqData.mDataFormat);
    if ([self checkError:error] == NO) {
        NSLog(@"格式获取失败");
        return;
    }else {
        NSLog(@"格式获取成功");
    }
    
    //创建新的队列
    error = AudioQueueNewOutput(&aqData.mDataFormat, HandleOutputBuffer, &aqData, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &aqData.mQueue);
    if ([self checkError:error] == NO) {
        NSLog(@"队列创建失败");
        return;
    }else {
        NSLog(@"队列创建成功");
    }
    
    //得到最大包的大小
    UInt32 maxPacketSize;
    UInt32 propertySize = sizeof(maxPacketSize);
    error = AudioFileGetProperty(aqData.mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &propertySize, &maxPacketSize);
    if ([self checkError:error] == NO) {
        NSLog(@"取最大包大小失败");
        return;
    }else {
        NSLog(@"最大包大小为：%zd",maxPacketSize);
    }
    //计算buffer size大小
    DeriveBufferSize(aqData.mDataFormat, maxPacketSize, 0.5, &aqData.bufferByteSize, &aqData.mNumPacketsToRead);
    
    
    bool isFormatVBR = (aqData.mDataFormat.mBytesPerPacket == 0 ||aqData.mDataFormat.mFramesPerPacket == 0);

    if (isFormatVBR) {
        aqData.mPacketDescs =(AudioStreamPacketDescription*) malloc (aqData.mNumPacketsToRead * sizeof (AudioStreamPacketDescription));
    } else {
        aqData.mPacketDescs = NULL;
    }
    
    aqData.mCurrentPacket = 0;
    //缓存
    for (int i = 0; i < kNumberBuffers; ++i) {
        error = AudioQueueAllocateBuffer(aqData.mQueue, aqData.bufferByteSize, &aqData.mBuffers[i]);
        if (error != NO) {
            NSLog(@"缓存失败");
            return;
        }else {
            NSLog(@"缓存成功");
        }
        HandleOutputBuffer(&aqData,aqData.mQueue,aqData.mBuffers[i]);
    }
    
    Float32 gain = 10.0;
    // Optionally, allow user to override gain setting here
    AudioQueueSetParameter (
                            aqData.mQueue,
                            kAudioQueueParam_Volume,
                            gain
                            );
    aqData.mIsRunning = true;
    AudioQueueStart(aqData.mQueue, NULL);
    
    printf("Playing...\n");
    
    //启动runLoop
    //方法1
//    do {
//        CFRunLoopRunInMode(kCFRunLoopDefaultMode,0.25,false);
//    } while (aqData.mIsRunning);
    //方法2
    [[NSRunLoop currentRunLoop] run];
    
}

- (BOOL)checkError:(int)error {
    if (error == noErr) {
        return YES;
    }
    if (error == kAudioFileUnspecifiedError) {
        NSLog(@"kAudioFileUnspecifiedError");
    } else if(error == kAudioFileUnsupportedFileTypeError){
        NSLog(@"kAudioFileUnsupportedFileTypeError");
    }else if(error == kAudioFileUnsupportedDataFormatError){
        NSLog(@"kAudioFileUnsupportedDataFormatError");
    }else if(error == kAudioFileUnsupportedPropertyError){
        NSLog(@"kAudioFileUnsupportedPropertyError");
    }else if(error == kAudioFileBadPropertySizeError){
        NSLog(@"kAudioFileBadPropertySizeError");
    }else if(error == kAudioFilePermissionsError){
        NSLog(@"kAudioFilePermissionsError");
    }else if(error == kAudioFileNotOptimizedError){
        NSLog(@"kAudioFileNotOptimizedError");
    }else if(error == kAudioFileInvalidChunkError){
        NSLog(@"kAudioFileInvalidChunkError");
    }else if(error == kAudioFileDoesNotAllow64BitDataSizeError){
        NSLog(@"kAudioFileDoesNotAllow64BitDataSizeError");
    }else if(error == kAudioFileInvalidPacketOffsetError){
        NSLog(@"kAudioFileInvalidPacketOffsetError");
    }else if(error == kAudioFileInvalidFileError){
        NSLog(@"kAudioFileInvalidFileError");
    }else if(error == kAudioFileOperationNotSupportedError){
        NSLog(@"kAudioFileOperationNotSupportedError");
    }else if(error == kAudioFileNotOpenError){
        NSLog(@"kAudioFileNotOpenError");
    }else if(error == kAudioFileEndOfFileError){
        NSLog(@"kAudioFileEndOfFileError");
    }else if(error == kAudioFilePositionError){
        NSLog(@"kAudioFilePositionError");
    }else if(error == kAudioFileFileNotFoundError){
        NSLog(@"kAudioFileFileNotFoundError");
    }
    
    return NO;
}





@end
