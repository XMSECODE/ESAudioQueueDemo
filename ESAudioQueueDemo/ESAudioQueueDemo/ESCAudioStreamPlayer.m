//
//  ESCAudioStreamPlayer.m
//  ESAudioQueueDemo
//
//  Created by xiang on 2018/7/18.
//  Copyright © 2018年 XMSECODE. All rights reserved.
//

#import "ESCAudioStreamPlayer.h"

@interface ESCAudioStreamPlayer () {
    
    AudioStreamBasicDescription audioDescription;///音频参数
    
    AudioQueueRef audioQueue;//音频播放队列
    
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];//音频缓存
    
    BOOL audioQueueUsed[QUEUE_BUFFER_SIZE];
}

@property (nonatomic,assign)BOOL isFirstPlay;

@property(nonatomic,strong)NSMutableArray* cachDataArray;

@property(nonatomic,assign)NSInteger enqueueDataCount;

@property(nonatomic,strong)dispatch_queue_t playQueue;

@property(nonatomic,assign)BOOL callBackHaveNoDo;

@end

@implementation ESCAudioStreamPlayer

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                  formatID:(AudioFormatID)formatID
               formatFlags:(AudioFormatFlags)formatFlags
          channelsPerFrame:(NSInteger)channelsPerFrame
            bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket{
    if (self = [super init]) {
        self.playQueue = dispatch_queue_create("audio queue play queue", DISPATCH_QUEUE_SERIAL);
        self.isFirstPlay =YES;
        
        audioDescription.mSampleRate              = sampleRate;//采样率
        audioDescription.mFormatID                = formatID;
        audioDescription.mFormatFlags             = formatFlags;
        audioDescription.mChannelsPerFrame        = channelsPerFrame;///单声道
        audioDescription.mFramesPerPacket         = framesPerPacket;//每一个packet一侦数据
        audioDescription.mBitsPerChannel          = bitsPerChannel;//每个采样点16bit量化
        audioDescription.mBytesPerFrame           = (audioDescription.mBitsPerChannel / 8) * audioDescription.mChannelsPerFrame;
        audioDescription.mBytesPerPacket          = audioDescription.mBytesPerFrame * audioDescription.mFramesPerPacket;

        [self setupAudioQueue];
    }
    return self;
   
}

- (void)dealloc {
    if (audioQueue !=nil) {
        AudioQueueStop(audioQueue,true);
    }
    audioQueue =nil;
    NSLog(@"dataPlayer dealloc...");
    
}

static void AudioPlayerAQInputCallback(void* inUserData,AudioQueueRef outQ, AudioQueueBufferRef outQB) {
    ESCAudioStreamPlayer* player = (__bridge ESCAudioStreamPlayer*)inUserData;
    [player playerCallback:outQB];
    NSLog(@"player callback");
}

- (void)setupAudioQueue {
    OSStatus status = AudioQueueNewOutput(&audioDescription,AudioPlayerAQInputCallback, (__bridge void*)self,nil,nil,0, &audioQueue);//使用player的内部线程播放
    if (status != 0) {
        NSLog(@"start failed!==%d",(int)status);
        return;
    }
    self.cachDataArray = [NSMutableArray array];
    //初始化音频缓冲区
    for (int i =0; i <QUEUE_BUFFER_SIZE; i++) {
        int result =AudioQueueAllocateBuffer(audioQueue,MIN_SIZE_PER_FRAME, &audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d", i, result);
    }
    
    NSLog(@"dataPlayer reset");
    
}

- (void)stop {
    if (audioQueue !=nil) {
        AudioQueueStop(audioQueue,true);
        AudioQueueReset(audioQueue);
    }
    audioQueue =nil;
    
}

- (void)play:(NSData *)data {
    dispatch_async(self.playQueue, ^{
        [self.cachDataArray addObject:data];
        
        if (_isFirstPlay) {
            AudioQueueStart(audioQueue,NULL);
            _isFirstPlay =NO;
        }
        if (self.enqueueDataCount < QUEUE_BUFFER_SIZE) {
            [self enqueueBuffers];
            self.enqueueDataCount++;
        }
    });
}

- (void)enqueueBuffers {
    
    if (self.cachDataArray.count == 0 || self.cachDataArray == nil) {
        NSLog(@"data array is nil %d",self.enqueueDataCount);
        if (self.callBackHaveNoDo == YES) {
            self.enqueueDataCount--;
            self.callBackHaveNoDo = NO;
        }
        return;
    }
    
    AudioQueueBufferRef audioQueueBuffer =NULL;
    
    audioQueueBuffer = [self getNotUsedBuffer];
    if (audioQueueBuffer ==NULL) {
        NSLog(@"find't no used buffer");
        return;
    }else {
        
    }
    
    NSData *firstData = self.cachDataArray.firstObject;
    [self.cachDataArray removeObjectAtIndex:0];

    NSLog(@"last count packet %d",self.cachDataArray.count);

    
    audioQueueBuffer->mAudioDataByteSize = firstData.length;
    
    Byte* audiodata = (Byte*)audioQueueBuffer->mAudioData;
    
    void *data = (void *)[firstData bytes];
    
    memcpy(audiodata, data, firstData.length);
    
    OSStatus status = AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffer,0,NULL);
    if (status != 0) {
        NSLog(@"en queue buffer failed! == %d",(int)status);
    }else {
//        NSLog(@"DataPlayer play dataSize:%d", firstData.length);
    }
}

- (AudioQueueBufferRef)getNotUsedBuffer {
    for (int i =0; i <QUEUE_BUFFER_SIZE; i++) {
        if (NO == audioQueueUsed[i]) {
            audioQueueUsed[i] = YES;
            return audioQueueBuffers[i];
        }
    }
    return NULL;
}

- (void)playerCallback:(AudioQueueBufferRef)outQB {
    dispatch_sync(self.playQueue, ^{
        for (int i =0; i <QUEUE_BUFFER_SIZE; i++) {
            if (outQB ==audioQueueBuffers[i]) {
                audioQueueUsed[i] = NO;
            }
        }
        self.callBackHaveNoDo = YES;
        [self enqueueBuffers];
    });
}

@end
