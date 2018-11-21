//
//  ESCAudioQueueRecorder.m
//  ESAudioQueueDemo
//
//  Created by xiang on 2018/7/19.
//  Copyright © 2018年 XMSECODE. All rights reserved.
//

#import "ESCAudioRecorder.h"
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface ESCAudioRecorder () {
    AudioStreamBasicDescription audioDescription;///音频参数
    
    AudioQueueRef audioQueue;
    
    AudioQueueBufferRef audioQueueBuffers[3];//音频缓存
}

@property(nonatomic,strong)NSURL* recordFileUrl;

@property(nonatomic,strong)AVAudioRecorder* recorder;

@property(nonatomic,strong)NSDictionary* recordSetting;

@property(nonatomic,strong)AVAudioFormat* audioFormat;

@end

@implementation ESCAudioRecorder

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket {
    if (self = [super init]) {
        //设置参数
        
        audioDescription.mSampleRate              = sampleRate;//采样率
        audioDescription.mFormatID                = formatID;
        audioDescription.mFormatFlags             = formatFlags;
        audioDescription.mChannelsPerFrame        = channelsPerFrame;///单声道
        audioDescription.mFramesPerPacket         = framesPerPacket;//每一个packet一侦数据
        audioDescription.mBitsPerChannel          = bitsPerChannel;//每个采样点16bit量化
        audioDescription.mBytesPerFrame           = (audioDescription.mBitsPerChannel / 8) * audioDescription.mChannelsPerFrame;
        audioDescription.mBytesPerPacket          = audioDescription.mBytesPerFrame * audioDescription.mFramesPerPacket;
        self.audioFormat = [[AVAudioFormat alloc] initWithStreamDescription:&(audioDescription)];
    }
    return self;
}

- (void)startRecordToFilePath:(NSString *)filePath {
    AVAudioSession *session = [AVAudioSession sharedInstance];
    NSError *sessionError;
    //设置我们需要的功能
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&sessionError];
    if (session == nil) {
        NSLog(@"Error creating session: %@",[sessionError description]);
    }else{
        //设置成功则启动激活会话
        [session setActive:YES error:nil];
    }
    //录制文件的路径
    self.recordFileUrl = [NSURL fileURLWithPath:filePath];

    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 10.0) {
        //iOS10之前设置参数为字典设置
        NSDictionary *dict = @{AVSampleRateKey:@(audioDescription.mSampleRate),//采样率 8000/11025/22050/44100/96000（影响音频的质量）
                               AVFormatIDKey:@(audioDescription.mFormatID),// 音频格式
                               AVLinearPCMBitDepthKey:@(audioDescription.mBitsPerChannel), //采样位数 8、16、24、32, 默认为16
                               AVNumberOfChannelsKey:@(audioDescription.mChannelsPerFrame),// 音频通道数 1 或 2
                               AVEncoderAudioQualityKey:@(AVAudioQualityHigh),//录音质量
                               AVLinearPCMIsFloatKey:@(NO),
                               };
        self.recorder = [[AVAudioRecorder alloc] initWithURL:self.recordFileUrl settings:dict error:&sessionError];
    }else {
        //audioDescription为第一步创建的格式对象
        self.audioFormat = [[AVAudioFormat alloc] initWithStreamDescription:&(audioDescription)];
        //iOS10后可以直接传入AVAudioFormat对象
        self.recorder = [[AVAudioRecorder alloc] initWithURL:self.recordFileUrl format:self.audioFormat error:&sessionError];
    }
    
    if (self.recorder) {
        [self.recorder record];
    }else{
        NSLog(@"音频格式和文件存储格式不匹配,无法初始化Recorder");
    }
}

- (void)stopRecordToFile {
    [self.recorder stop];
}

void audioQueueInputCallback(
                                        void * __nullable               inUserData,
                                        AudioQueueRef                   inAQ,
                                        AudioQueueBufferRef             inBuffer,
                                        const AudioTimeStamp *          inStartTime,
                                        UInt32                          inNumberPacketDescriptions,
                                        const AudioStreamPacketDescription * __nullable inPacketDescs) {
    
    ESCAudioRecorder *recorder = (__bridge ESCAudioRecorder *)(inUserData);
    if (recorder.delegate && [recorder.delegate respondsToSelector:@selector(ESCAudioRecorderReceiveAudioData:)]) {
        NSData *data = [NSData dataWithBytes:inBuffer->mAudioData length:inBuffer->mAudioDataByteSize];
        [recorder.delegate ESCAudioRecorderReceiveAudioData:data];
    }
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
}

- (void)startRecordToStream {
    OSStatus status = AudioQueueNewInput(&(audioDescription), audioQueueInputCallback, (__bridge void * _Nullable)(self), nil, nil, 0, &audioQueue);
    if (status != 0) {
        NSLog(@"new failed!==%d",(int)status);
        return;
    }
    //初始化音频缓冲区
    for (int i =0; i <3; i++) {
        int result =AudioQueueAllocateBuffer(audioQueue,2048, &audioQueueBuffers[i]);///创建buffer区，MIN_SIZE_PER_FRAME为每一侦所需要的最小的大小，该大小应该比每次往buffer里写的最大的一次还大
        NSLog(@"AudioQueueAllocateBuffer i = %d,result = %d", i, result);
        AudioQueueEnqueueBuffer(audioQueue, audioQueueBuffers[i], 0, NULL);
    }
    status = AudioQueueStart(audioQueue, NULL);
    if (status != 0) {
        NSLog(@"start failed!==%d",(int)status);
        return;
    }
}

- (void)stopRecordToStream {
    AudioQueueStop(audioQueue, YES);
}

@end
