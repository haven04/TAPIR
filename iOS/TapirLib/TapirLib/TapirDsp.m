//
//  TapirDsp.m
//  TapirLib
//
//  Created by Jimin Jeon on 11/20/13.
//  Copyright (c) 2013 Jimin Jeon. All rights reserved.
//

#import "TapirDsp.h"

//IQ Modulation
static void generateCarrier(DSPSplitComplex * carrier, const int length, const float samplingFreq, const float carrierFreq)
{
    // MATLAB code
    // tC = (0:1/Fs:(length(signal)-1)/Fs);
    // Carrier = exp(1i * (2 * pi * Fc * tC) )';
    
    float initState = 0;
    float inc = 2 * M_PI * carrierFreq/(float)samplingFreq;
    float * carrierIndex = malloc(sizeof(float) * length);
    
    vDSP_vramp(&initState, &inc, carrierIndex, 1, length);
    vvsincosf(carrier->imagp, carrier->realp, carrierIndex, &length);
    
    free(carrierIndex);
}

void scaleFloatSignal(const float * source, float * dest, const int length, const float scale)
{
    vDSP_vsmul(source, 1, &scale, dest, 1, length);
}
void scaleCompSignal(const DSPSplitComplex * source, DSPSplitComplex * dest, const int length, const float scale)
{
    scaleFloatSignal(source->realp, dest->realp, length, scale);
    scaleFloatSignal(source->imagp, dest->imagp, length, scale);
}

void maximizeSignal(const float * source, float * dest, const int length, const float maximum)
{
    float maxVal;
    vDSP_maxmgv(source, 1, &maxVal, length);
    scaleFloatSignal(source, dest, length, maximum / maxVal);
}


void iqDemodulate(const float * signal, DSPSplitComplex * destSignal, const int length, const float samplingFreq, const float carrierFreq)
{
    //    MATLAB Code
    //    realRx = signal .* real(carrier);
    //    imagRx = signal .* imag(carrier);
    //    basebandSig = realRx + 1i*imagRx;
    
    DSPSplitComplex carrier;
    carrier.realp = malloc(sizeof(float) * length);
    carrier.imagp = malloc(sizeof(float) * length);
    //    float scale = sqrt(2.f);
    float scale = M_SQRT2;
    
    generateCarrier(&carrier, length, samplingFreq, carrierFreq);
    scaleCompSignal(&carrier, &carrier, length, scale);
    vDSP_zrvmul(&carrier, 1, signal, 1, destSignal, 1, length);
    
    free(carrier.realp);
    free(carrier.imagp);
}

void iqModulate(const DSPSplitComplex * signal, float * destSignal, const int length, const float samplingFreq, const float carrierFreq)
{
    //    MATLAB Code
    //    rePulse = real(signal) .* real(carrier);
    //    imPulse = imag(signal) .* imag(carrier);
    //    modulatedSig = rePulse + imPulse;
    
    DSPSplitComplex carrier;
    carrier.realp = malloc(sizeof(float) * length);
    carrier.imagp = malloc(sizeof(float) * length);

    generateCarrier(&carrier, length, samplingFreq, carrierFreq);
    
    vDSP_vmul(signal->realp, 1, carrier.realp, 1, signal->realp, 1, length);
    vDSP_vmul(signal->imagp, 1, carrier.imagp, 1, signal->imagp, 1, length);

    vDSP_vadd(signal->realp, 1, signal->imagp,1 , destSignal, 1, length);
    scaleFloatSignal(destSignal, destSignal, length, 2.0f);
    
    free(carrier.realp);
    free(carrier.imagp);
}

//FFT

static int calculateLogLength(int length)
{
    int count = 0;
    while(length > 0)
    {
        length >>= 1;
        ++count;
    }
    --count;
    return count;
}

void fftComplexForward(const DSPSplitComplex * signal, DSPSplitComplex * dest, const int fftLength)
{
    int logLen = calculateLogLength(fftLength);
    FFTSetup setup = vDSP_create_fftsetup(logLen, FFT_RADIX2);
    vDSP_fft_zop(setup, signal, 1, dest, 1, logLen, FFT_FORWARD);
    vDSP_destroy_fftsetup(setup);
}

void fftComplexInverse(const DSPSplitComplex * signal, DSPSplitComplex * dest, const int fftLength)
{
    int logLen = calculateLogLength(fftLength);
    FFTSetup setup = vDSP_create_fftsetup(logLen, FFT_RADIX2);
    vDSP_fft_zop(setup, signal, 1, dest, 1, logLen, FFT_INVERSE);
    vDSP_destroy_fftsetup(setup);    
}

int mergeBitsToIntegerValue(const int * intArray, int arrLength)
{
    int retVal = 0;
    for(int i=0; i<arrLength; ++i)
    {
        retVal += (intArray[i] & 1) << (arrLength - 1 - i);
    }
    return retVal;
}
void divdeIntIntoBits(const int src, int * arr, int arrLength)
{
    int input = src;
    for(int i = 0; i < arrLength; ++i)
    {
        arr[arrLength - i - 1] = (input & 1);
        input >>= 1;
    }
    
}



