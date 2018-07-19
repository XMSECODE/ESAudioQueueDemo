//
//  ESCAudioQueueRecorder.h
//  ESAudioQueueDemo
//
//  Created by xiang on 2018/7/19.
//  Copyright © 2018年 XMSECODE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

@protocol ESCAudioRecorderDelegate <NSObject>

- (void)ESCAudioRecorderReceiveAudioData:(NSData *)audioData;

@end

@interface ESCAudioRecorder : NSObject

@property(nonatomic,weak)id delegate;

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket;

- (void)startRecordToFilePath:(NSString *)filePath;
- (void)stopRecordToFile;

- (void)startRecordToStream;
- (void)stopRecordToStream;

@end
