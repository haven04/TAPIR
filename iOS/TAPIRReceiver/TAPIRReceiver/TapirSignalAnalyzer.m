//
//  TapirSignalAnalyzer.m
//  TAPIRReceiver
//
//  Created by Jimin Jeon on 12/1/13.
//  Copyright (c) 2013 dilu. All rights reserved.
//

#import "TapirSignalAnalyzer.h"
#import "TapirConfig.h"

@interface TapirSignalAnalyzer()

-(void) cutCentralRegion:(const DSPSplitComplex *)src dest:(DSPSplitComplex * )dest signalLength:(const int)signalLength destLength:(const int)destLength firstHalfLength:(const int)fHalfLength;
@end

@implementation TapirSignalAnalyzer

- (id) init
{
    return nil;
}
//- (void)cutSymbolDataRegion()

- (id)initWithConfig:(TapirConfig *)_cfg
{
    if(self == [super init])
    {
        cfg = _cfg;
        
        convertedSignal.realp = malloc(sizeof(float) * [cfg kSymbolLength]);
        convertedSignal.imagp = malloc(sizeof(float) * [cfg kSymbolLength]);
        roiSignal.realp = malloc(sizeof(float) * [cfg kNoTotalSubcarriers]);
        roiSignal.imagp = malloc(sizeof(float) * [cfg kNoTotalSubcarriers]);
        estimatedSignal.realp = malloc(sizeof(float) * [cfg kNoTotalSubcarriers]);
        estimatedSignal.imagp = malloc(sizeof(float) * [cfg kNoTotalSubcarriers]);
        pilotRemovedSignal.realp = malloc(sizeof(float) * [cfg kNoDataSubcarriers]);
        pilotRemovedSignal.imagp = malloc(sizeof(float) * [cfg kNoDataSubcarriers]);

        demod = malloc(sizeof(float) * [cfg kNoDataSubcarriers]);
        deinterleaved = malloc(sizeof(float) * [cfg kNoDataSubcarriers]);
        decoded = malloc(sizeof(int) * [cfg kDataBitLength]);

        pilotMgr = [[TapirPilotManager alloc] initWithPilot:[cfg kPilotData] index:[cfg kPilotLocation] length:[cfg kPilotLength]];
        
        chanEstimator = [[TapirLSChannelEstimator alloc] initWithPilot:pilotMgr channelLength:[cfg kNoTotalSubcarriers]];
        
        modulator = [[TapirPskModulator alloc] initWithSymbolRate:[cfg kModulationRate]];
        interleaver = [[TapirMatrixInterleaver alloc] initWithNRows:[cfg kInterleaverRows] NCols:[cfg kInterleaverCols]];
        vitdec = [[TapirViterbiDecoder alloc] initWithTrellisArray:[cfg kTrellisArray]];
        
    }
    return self;
    
}


- (void) cutCentralRegion:(const DSPSplitComplex *)src dest:(DSPSplitComplex * )dest signalLength:(const int)signalLength destLength:(const int)destLength firstHalfLength:(const int)fHalfLength
{
    int lastHalfCutLength = destLength - fHalfLength;
    int sigLastHalfStPoint = signalLength - lastHalfCutLength;
    int cpLHMemSize = lastHalfCutLength * sizeof(float);
    int cpFHMemSize = fHalfLength * sizeof(float);
    
    memcpy(dest->realp, src->realp + sigLastHalfStPoint, cpLHMemSize);
    memcpy(dest->imagp, src->imagp + sigLastHalfStPoint, cpLHMemSize);
    memcpy(dest->realp + lastHalfCutLength, src->realp, cpFHMemSize);
    memcpy(dest->imagp + lastHalfCutLength, src->imagp, cpFHMemSize);
}

-(char)decodeBlock:(const float *)signal
{
    //Freq Downconversion & FFT, and cut central spectrum region
    iqDemodulate(signal, &convertedSignal, [cfg kSymbolLength], [cfg kAudioSampleRate], [cfg kCarrierFrequency]);

    // TODO: LPF (for real & imag both)
    
    //FFT
    fftComplexForward(&convertedSignal, &convertedSignal, [cfg kSymbolLength]);
    
    [self cutCentralRegion:&convertedSignal dest:&roiSignal signalLength:[cfg kSymbolLength] destLength:[cfg kNoTotalSubcarriers] firstHalfLength:[cfg kNoTotalSubcarriers]/2];

    //Channel Estimation
    [chanEstimator channelEstimate:&roiSignal dest:&estimatedSignal];
    
    //Pilot Remove
    [pilotMgr removePilotFrom:&estimatedSignal dest:&pilotRemovedSignal srcLength:[cfg kNoTotalSubcarriers]];

    //Demodulation
    [modulator demodulate:&pilotRemovedSignal dest:demod length:[cfg kNoDataSubcarriers]];
    //Deinterleaver
    [interleaver deinterleave:demod to:deinterleaved];
    
    // Viterbi Decoding
    [vitdec decode:deinterleaved dest:decoded srcLength:[cfg kNoDataSubcarriers] extLength:[cfg kDecoderExtTracebackLength]];

    return ((char)mergeBitsToIntegerValue(decoded, [cfg kDataBitLength]));

}

-(NSString *)analyze:(float *)signal
{
    NSMutableString * result = [[NSMutableString alloc] init];
    
    //skip preambleInterval
    float * ptr = signal + [cfg kIntervalAfterPreamble];
    for(int i=0;i < [cfg kMaximumSymbolLength]; ++i)
    {
        float * curSymbol = (ptr + [cfg kCyclicPrefixLength]);
        char decodedChar = [self decodeBlock:curSymbol];
        if(decodedChar == ASCII_ETX) { break; }
        else
        {
            [result appendFormat:@"%c", decodedChar];
        }
        
        if( i != [cfg kMaximumSymbolLength])
        {
            ptr += ([cfg kGuardIntervalLength] + [cfg kSymbolWithCyclicExtLength]);
        }
    }
    return (NSString *)result;
    
}

- (void)dealloc
{
    free(convertedSignal.realp);
    free(convertedSignal.imagp);
    free(roiSignal.realp);
    free(roiSignal.imagp);
    free(estimatedSignal.realp);
    free(estimatedSignal.imagp);
    free(pilotRemovedSignal.realp);
    free(pilotRemovedSignal.imagp);
    free(demod);
    free(deinterleaved);
    free(decoded);
    
}

@end
