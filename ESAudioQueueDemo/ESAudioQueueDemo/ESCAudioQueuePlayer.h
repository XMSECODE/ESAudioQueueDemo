//
//  ESCAudioQueuePlayer.h
//  FFMPEG_STUDY
//
//  Created by xiangmingsheng on 2018/7/16.
//  Copyright © 2018年 XMSECODE. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ESCAudioQueuePlayer : NSObject

- (instancetype)initWithFilePath:(NSString *)filePath;

- (void)startPlay;

- (void)restartPlay;

- (void)stop;

- (void)pause;

- (void)continuePlay;

@end
