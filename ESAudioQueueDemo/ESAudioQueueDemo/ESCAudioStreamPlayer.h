//
//  ESCAudioStreamPlayer.h
//  ESAudioQueueDemo
//
//  Created by xiang on 2018/7/18.
//  Copyright © 2018年 XMSECODE. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>

#define QUEUE_BUFFER_SIZE 3//队列缓冲个数

#define MIN_SIZE_PER_FRAME 20480//每帧最小数据长度

@interface ESCAudioStreamPlayer : NSObject

- (instancetype)initWithSampleRate:(NSInteger)sampleRate
                          formatID:(AudioFormatID)formatID
                       formatFlags:(AudioFormatFlags)formatFlags
                  channelsPerFrame:(NSInteger)channelsPerFrame
                    bitsPerChannel:(NSInteger)bitsPerChannel
                   framesPerPacket:(NSInteger)framesPerPacket;

- (void)play:(NSData *)data;

- (void)stop;
@end
