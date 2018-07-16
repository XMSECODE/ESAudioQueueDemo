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


@interface ViewController ()

@property (nonatomic, strong) NSThread *playThread;

@property (nonatomic, strong) AVAudioPlayer *play;

@property(nonatomic,strong)ESCAudioQueuePlayer* audioPlayer;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    char *ss = [[[NSBundle mainBundle] pathForResource:@"test.pcm" ofType:nil] cStringUsingEncoding:kCFStringEncodingUTF8];
//    convertPcm2Wav(ss, "/Users/xiang/Desktop/pcmHeadt", 1, 8000);
    
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"G.E.M.邓紫棋 - 喜欢你.mp3" ofType:nil];
    self.audioPlayer = [[ESCAudioQueuePlayer alloc] initWithFilePath:filePath];
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

@end
