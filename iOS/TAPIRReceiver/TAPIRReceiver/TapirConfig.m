//
//  TapirConfig.m
//  TAPIRReceiver
//
//  Created by Jimin Jeon on 12/1/13.
//  Copyright (c) 2013 dilu. All rights reserved.
//

#import "TapirConfig.h"


@implementation TapirConfig
@synthesize  kAudioSampleRate, kAudioChannel;
@synthesize kPreambleLength, kSymbolLength, kCyclicPostfixLength, kCyclicPrefixLength, kGuardIntervalLength, kMaximumSymbolLength, kSymbolWithCyclicExtLength, kAudioBufferLength, kAudioMaxVolume;
@synthesize kPreambleBitLength, kPreambleBandwidth;
@synthesize kIntervalAfterPreamble;
@synthesize kCarrierFrequency, kNoDataSubcarriers;
@synthesize kPilotLength, kNoTotalSubcarriers;
@synthesize kModulationRate;
@synthesize kInterleaverRows, kInterleaverCols;
@synthesize kDecoderExtTracebackLength;
@synthesize kTrellisArray;
@synthesize kEncodingRate, kDataBitLength;
@synthesize kFilterDelayGuardLength;

static TapirConfig * sTapirConfig = nil;

+ (TapirConfig *) getInstance
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sTapirConfig = [[self alloc] init];
        [sTapirConfig initShared];
    });
    return sTapirConfig;
}

- (void)initShared;
{
    kAudioSampleRate = 44100.f;
    kAudioChannel = 1;
//    kAudioBitsPerChannel = 16;
    kAudioMaxVolume = 1.0f;

    kMaximumSymbolLength = 8;
    kPreambleBitLength = 4;
    kPreambleBandwidth = 441.f;
    kPreambleBit = malloc(sizeof(float) * kPreambleBitLength);
    kPreambleBit[0] = -1.f;
    kPreambleBit[1] = -1.f;
    kPreambleBit[2] = -1.f;
    kPreambleBit[3] = 1.f;
    
    kPreambleLength = (floor)((kAudioSampleRate * kPreambleBitLength) / kPreambleBandwidth);
    
    kSymbolLength = 2048;
    kCyclicPrefixLength = kSymbolLength / 2;
    kCyclicPostfixLength = kSymbolLength / 4;
    kGuardIntervalLength = 0;
    
    kIntervalAfterPreamble = kSymbolLength / 2;
    kSymbolWithCyclicExtLength = (kCyclicPrefixLength + kSymbolLength + kCyclicPostfixLength);
    
    kAudioBufferLength = kIntervalAfterPreamble +
                         kSymbolWithCyclicExtLength * kMaximumSymbolLength +
                        (kGuardIntervalLength) * (kMaximumSymbolLength-1);
    
    kCarrierFrequency = 20000.f;
    kNoDataSubcarriers = 16;
    
    //For Channel Estimator
    kPilotLength = 4;
    kNoTotalSubcarriers = kNoDataSubcarriers + kPilotLength;
    
    kPilotData.realp = malloc(sizeof(float) * kPilotLength);
    kPilotData.imagp = malloc(sizeof(float) * kPilotLength);
    kPilotData.realp[0] = 1.f;
    kPilotData.realp[1] = 1.f;
    kPilotData.realp[2] = 1.f;
    kPilotData.realp[3] = -1.f;
    
    kPilotData.imagp[0] = 0.f;
    kPilotData.imagp[1] = 0.f;
    kPilotData.imagp[2] = 0.f;
    kPilotData.imagp[3] = 0.f;
    
    kPilotLocation = malloc(sizeof(int) * kPilotLength);
    kPilotLocation[0] = 3;
    kPilotLocation[1] = 7;
    kPilotLocation[2] = 11;
    kPilotLocation[3] = 15;

    kModulationRate = 2;

    kInterleaverRows = 4;
    kInterleaverCols = kNoDataSubcarriers / kInterleaverRows;


    kTrellisArray = [[NSArray alloc] initWithObjects:
                     [[TapirTrellisCode alloc] initWithG:171],
                     [[TapirTrellisCode alloc] initWithG:133],
                     nil];

    kDecoderExtTracebackLength = 4;
    kEncodingRate = (int)[kTrellisArray count];
    kDataBitLength = kNoDataSubcarriers / kEncodingRate;
    
    kFilterDelayGuardLength = 100;

}

- (DSPSplitComplex *) kPilotData
{
    return &kPilotData;
}
- (int *) kPilotLocation
{
    return kPilotLocation;
}
- (float *) kPreambleBit
{
    return kPreambleBit;
}

- (void) dealloc
{
    free(kPilotData.realp);
    free(kPilotData.imagp);
    free(kPilotLocation);
    free(kPreambleBit);
}

@end
