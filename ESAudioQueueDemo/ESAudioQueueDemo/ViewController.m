//
//  ViewController.m
//  ESAudioQueueDemo
//
//  Created by xiangmingsheng on 2017/7/11.
//  Copyright © 2017年 XMSECODE. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "Base64.h"
#import "ESCAudioQueuePlayer.h"
#import "ESCAudioStreamPlayer.h"
#import "ESCAudioRecorder.h"

typedef struct {
    char fccID[4];
    int32_t dwSize;
    char fccType[4];
} HEADER;

typedef struct {
    char fccID[4];
    int32_t dwSize;
    int16_t wFormatTag;
    int16_t wChannels;
    int32_t dwSamplesPerSec;
    int32_t dwAvgBytesPerSec;
    int16_t wBlockAlign;
    int16_t uiBitsPerSample;
} FMT;

typedef struct {
    char fccID[4];
    int32_t dwSize;
} DATA;

#define sampleRate 8000
#define d_bitsPerChannel 16

@interface ViewController () <ESCAudioRecorderDelegate>

@property (nonatomic, strong) AVAudioPlayer *play;

@property(nonatomic,strong)ESCAudioQueuePlayer* audioPlayer;

@property(nonatomic,strong)ESCAudioStreamPlayer* streamPlayer;

@property(nonatomic,strong)ESCAudioRecorder* audioRecorder;
@property(nonatomic,copy)NSString* recordFilePath;
@property(nonatomic,strong)AVAudioPlayer* avaudioPlayer;


@property(nonatomic,strong)ESCAudioStreamPlayer* recorderFileStreamPlayer;
@property(nonatomic,strong)ESCAudioRecorder* audioStreamRecorder;
@property(nonatomic,copy)NSString* recordFileStreamPath;
@property(nonatomic,strong)NSFileHandle* audioStreamFileHandle;

@property(nonatomic,strong)ESCAudioRecorder* sameTimeRecorder;
@property(nonatomic,strong)ESCAudioStreamPlayer* sameTimePlayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSString *filePath = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).lastObject;
    self.recordFilePath = [NSString stringWithFormat:@"%@/test.pcm",filePath];
     self.recordFileStreamPath = [NSString stringWithFormat:@"%@/teststream.pcm",filePath];
}

int convertPcm2Wav(char *src_file, char *dst_file, int channels, int sample_rate) {
    int bits = 16; //以下是为了建立.wav头而准备的变量
    HEADER pcmHEADER;
    FMT pcmFMT;
    DATA pcmDATA;
    unsigned short m_pcmData;
    FILE *fp,*fpCpy;
    if((fp=fopen(src_file, "rb")) == NULL)//读取文件
    {
        printf("open pcm file %s error\n", src_file);
        return -1;
    }
    if((fpCpy=fopen(dst_file, "wb+")) == NULL) //为转换建立一个新文件
    {
        printf("create wav file error\n");
        return -1;
    } //以下是创建wav头的HEADER;但.dwsize未定，因为不知道Data的长度。
    strncpy(pcmHEADER.fccID,"RIFF",4);
    strncpy(pcmHEADER.fccType,"WAVE",4);
    fseek(fpCpy,sizeof(HEADER),1); //跳过HEADER的长度，以便下面继续写入wav文件的数据; //以上是创建wav头的HEADER;
    if(ferror(fpCpy)) {
        printf("error\n");
    } //以下是创建wav头的FMT;
    pcmFMT.dwSamplesPerSec=sample_rate;
    pcmFMT.dwAvgBytesPerSec=pcmFMT.dwSamplesPerSec*sizeof(m_pcmData);
    pcmFMT.uiBitsPerSample=bits;
    strncpy(pcmFMT.fccID,"fmt  ", 4);
    pcmFMT.dwSize=16;
    pcmFMT.wBlockAlign=2;
    pcmFMT.wChannels=channels;
    pcmFMT.wFormatTag=1; //以上是创建wav头的FMT;
    fwrite(&pcmFMT,sizeof(FMT),1,fpCpy); //将FMT写入.wav文件; //以下是创建wav头的DATA;  但由于DATA.dwsize未知所以不能写入.wav文件
    strncpy(pcmDATA.fccID,"data", 4);
    pcmDATA.dwSize=0; //给pcmDATA.dwsize  0以便于下面给它赋值
    fseek(fpCpy,sizeof(DATA),1); //跳过DATA的长度，以便以后再写入wav头的DATA;
    fread(&m_pcmData,sizeof(int16_t),1,fp); //从.pcm中读入数据
    while(!feof(fp)) //在.pcm文件结束前将他的数据转化并赋给.wav;
    { pcmDATA.dwSize+=2; //计算数据的长度；每读入一个数据，长度就加一；
        fwrite(&m_pcmData,sizeof(int16_t),1,fpCpy); //将数据写入.wav文件;
        fread(&m_pcmData,sizeof(int16_t),1,fp); //从.pcm中读入数据
    }
    fclose(fp); //关闭文件
    pcmHEADER.dwSize = 0; //根据pcmDATA.dwsize得出pcmHEADER.dwsize的值
    rewind(fpCpy); //将fpCpy变为.wav的头，以便于写入HEADER和DATA;
    fwrite(&pcmHEADER,sizeof(HEADER),1,fpCpy); //写入HEADER
    fseek(fpCpy,sizeof(FMT),1); //跳过FMT,因为FMT已经写入
    fwrite(&pcmDATA,sizeof(DATA),1,fpCpy); //写入DATA;
    fclose(fpCpy); //关闭文件
    return 0;
}

- (void)playPCMData {
    NSString *headPath = [[NSBundle mainBundle] pathForResource:@"pcmHead" ofType:nil];
    
    //    convertPcm2Wav([musicPath cStringUsingEncoding:NSUTF8StringEncoding], "/Users/xiang/Desktop/test.pcm", 1, 8000);
    
    NSData *headData = [NSData dataWithContentsOfFile:headPath];
    
    NSString *str = [headData base64EncodedString];
    
    NSLog(@"%@",str);
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"PrinRecord20170810120307.pcm" ofType:nil];
    NSData *fileData = [NSData dataWithContentsOfFile:filePath];
    
    NSMutableData *temData = [headData mutableCopy];
    [temData appendData:fileData];
    
    temData = [NSData dataWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"test.pcm" ofType:nil]];
    
    NSError *error;
    AVAudioPlayer *play = [[AVAudioPlayer alloc] initWithData:temData error:&error];
    if (error) {
        NSLog(@"error = %@",error);
        return;
    }else {
        BOOL issuccess = [play prepareToPlay];
        if (issuccess) {
            NSLog(@"success");
            issuccess = [play play];
            if (issuccess) {
                NSLog(@"ff");
            }
        }
        self.play = play;
        return;
    }
}

#pragma mark - Action
- (IBAction)didClickStartButton:(id)sender {
    if (self.audioPlayer == nil) {
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"G.E.M.邓紫棋 - 喜欢你.mp3" ofType:nil];
        self.audioPlayer = [[ESCAudioQueuePlayer alloc] initWithFilePath:filePath];
    }
    [self.audioPlayer startPlay];
}

- (IBAction)didClickPauseButton:(id)sender {
    [self.audioPlayer pause];
}

- (IBAction)didClickStopButton:(id)sender {
    [self.audioPlayer stop];
    self.audioPlayer = nil;
}

- (IBAction)didClickStopPCMDataButton:(id)sender {
    [self.streamPlayer stop];
}

- (IBAction)didClickPlayPCMStreamButton:(id)sender {
//    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:44100 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:2 bitsPerChannel:16 framesPerPacket:1];
//    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"vocal.pcm" ofType:nil];
    
//    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:44100 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger  channelsPerFrame:2 bitsPerChannel:16 framesPerPacket:1];
//    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"vocal2.pcm" ofType:nil];
    
//        self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
//        NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"1708101114545.pcm" ofType:nil];
    
    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:8000 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:2 bitsPerChannel:16 framesPerPacket:1];
    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"8000_1_16.pcm" ofType:nil];
    
//    self.streamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:44100 formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:16 framesPerPacket:1];
//    NSString *pcmFilePath = [[NSBundle mainBundle] pathForResource:@"tem.pcm" ofType:nil];
    
    NSData *pcmData = [NSData dataWithContentsOfFile:pcmFilePath];
    NSInteger count = pcmData.length / 2000;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < count; i++) {
            NSInteger lenth = pcmData.length / count;
            NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
            //            NSLog(@"encode buffer %d==%d",i,lenth);
            [self.streamPlayer play:pcmDatarange];
        }
        //模拟中断
        //        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_global_queue(0, 0), ^{
        //            for (int i = 0; i < count; i++) {
        //                NSInteger lenth = pcmData.length / count;
        //                NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
        //                //            NSLog(@"encode buffer %d==%d",i,lenth);
        //                [self.streamPlayer play:pcmDatarange];
        //
        //            }
        //        });
    });
}

- (IBAction)didClickRecordAudioFileButton:(id)sender {
    if (self.audioRecorder == nil) {
        self.audioRecorder = [[ESCAudioRecorder alloc] initWithSampleRate:sampleRate formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:d_bitsPerChannel framesPerPacket:1];
    }
    
    [self.audioRecorder startRecordToFilePath:self.recordFilePath];
}

- (IBAction)didClickStopRecordAudioFileButton:(id)sender {
    [self.audioRecorder stopRecordToFile];
}

- (IBAction)didClickStartPlayRecordAudioFileButton:(id)sender {
    
    
    NSData *pcmData = [NSData dataWithContentsOfFile:self.recordFilePath];
    NSError *error;
    AVAudioPlayer *avaudioPlayer = [[AVAudioPlayer alloc] initWithData:pcmData error:&error];
    [avaudioPlayer play];
    self.avaudioPlayer = avaudioPlayer;
    
}

- (IBAction)didClickStopPlayRecordAudioFileButton:(id)sender {
    [self.avaudioPlayer stop];
}

- (IBAction)didClickRecordFileStreamButton:(id)sender {
    
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:self.recordFileStreamPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:self.recordFileStreamPath error:&error];
    }
    [[NSFileManager defaultManager] createFileAtPath:self.recordFileStreamPath contents:nil attributes:nil];
    self.audioStreamFileHandle = [NSFileHandle fileHandleForWritingAtPath:self.recordFileStreamPath];
    
    self.audioStreamRecorder = [[ESCAudioRecorder alloc] initWithSampleRate:sampleRate formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:d_bitsPerChannel framesPerPacket:1];
    self.audioStreamRecorder.delegate = self;
    [self.audioStreamRecorder startRecordToStream];
}

- (IBAction)didClickStopRecordFileStreamButton:(id)sender {
    [self.audioStreamRecorder stopRecordToStream];
    [self.audioStreamFileHandle closeFile];
}

- (IBAction)didClickStartPlayFileStreamButton:(id)sender {
    
    NSData *pcmData = [NSData dataWithContentsOfFile:self.recordFileStreamPath];
    
    self.recorderFileStreamPlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:sampleRate formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:d_bitsPerChannel framesPerPacket:1];
    NSInteger count = 100;
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        for (int i = 0; i < count; i++) {
            NSInteger lenth = pcmData.length / count;
            NSData *pcmDatarange = [pcmData subdataWithRange:NSMakeRange(i * lenth, lenth)];
            //            NSLog(@"encode buffer %d==%d",i,lenth);
            [self.recorderFileStreamPlayer play:pcmDatarange];
        }
    });
}
- (IBAction)didClickStopPlayFileStreamButton:(id)sender {
    [self.recorderFileStreamPlayer stop];
}
- (IBAction)didClickrecordPlayButton:(id)sender {
    if (self.sameTimePlayer == nil) {
        self.sameTimePlayer = [[ESCAudioStreamPlayer alloc] initWithSampleRate:sampleRate formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:d_bitsPerChannel framesPerPacket:1];
        self.sameTimeRecorder = [[ESCAudioRecorder alloc] initWithSampleRate:sampleRate formatID:kAudioFormatLinearPCM formatFlags:kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked channelsPerFrame:1 bitsPerChannel:d_bitsPerChannel framesPerPacket:1];
        self.sameTimeRecorder.delegate = self;
        [self.sameTimeRecorder startRecordToStream];
    }
}

- (IBAction)didClickStopRecordPlayButton:(id)sender {
    [self.sameTimePlayer stop];
    [self.sameTimeRecorder stopRecordToStream];
    self.sameTimePlayer = nil;
    self.sameTimeRecorder = nil;
}

#pragma mark - ESCAudioRecorderDelegate
- (void)ESCAudioRecorderReceiveAudioData:(NSData *)audioData {
    if (self.audioStreamFileHandle) {
        [self.audioStreamFileHandle writeData:audioData];
    }
    if (self.sameTimePlayer) {
        [self.sameTimePlayer play:audioData];
    }
}
@end
