//
//  TapirDsp.h
//  TapirLib
//
//  Created by Jimin Jeon on 11/20/13.
//  Copyright (c) 2013 Jimin Jeon. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

//Frequency Downconversion
void iqDemodulate(const float * signal, DSPSplitComplex * destSignal, const int length, const float samplingFreq, const float carrierFreq);

//Frequency Upconversion
void iqModulate(const DSPSplitComplex * signal, float * destSignal, const int length, const float samplingFreq, const float carrierFreq);


void scaleFloatSignal(const float * source, float * dest, const int length, const float scale);
void scaleCompSignal(const DSPSplitComplex * source, DSPSplitComplex * dest, const int length, const float scale);

void maximizeSignal(const float * source, float * dest, const int length, const float maximum);


//FFT
void fftComplexForward(const DSPSplitComplex * signal, DSPSplitComplex * dest, const int fftLength);
void fftComplexInverse(const DSPSplitComplex * signal, DSPSplitComplex * dest, const int fftLength);

int mergeBitsToIntegerValue(const int * intArray, int arrLength);
void divdeIntIntoBits(const int src, int * arr, int arrLength);