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

@property(nonatomic,assign)AQPlayerState *playerState;

@property (nonatomic, strong) AVAudioPlayer *play;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    char *ss = [[[NSBundle mainBundle] pathForResource:@"test.pcm" ofType:nil] cStringUsingEncoding:kCFStringEncodingUTF8];
//    convertPcm2Wav(ss, "/Users/xiang/Desktop/pcmHeadt", 1, 8000);
    
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



#pragma mark - Action
- (IBAction)didClickStartButton:(id)sender {
    
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
    NSString *musicPath = [[NSBundle mainBundle] pathForResource:@"test.pcm" ofType:nil];
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
