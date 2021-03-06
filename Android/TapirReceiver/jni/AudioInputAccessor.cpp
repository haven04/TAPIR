/*
 * AudioInputAccessor.cpp
 *
 *  Created on: Mar 13, 2014
 *      Author: Jimin
 */

#include "AudioInputAccessor.h" 
 
static const float kShortMax = (float)(SHRT_MAX);
 
void recorderCallback(SLAndroidSimpleBufferQueueItf bq, void *context)
{
	((AudioInputAccessor *)context)->newInputBuffer();
};

AudioInputAccessor::AudioInputAccessor(int frameSize, Tapir::SignalDetector * detector)
:m_frameSize(frameSize),
m_frameByteSize(m_frameSize * sizeof(short)),
m_detector(detector),
m_objEngine(nullptr),
m_engine(nullptr),
m_objRecorder(nullptr),
m_recorder(nullptr),
m_bufferQueue(nullptr),
m_curBufferIdx(0),
m_noBuffer(3),
m_buffer(nullptr),
m_floatBuffer(new float[m_frameSize])
{ 

	//Allocate Buffer
	m_buffer = new short*[m_noBuffer];
	for(int i=0; i<m_noBuffer; ++i)
	{ m_buffer[i] = new short[m_frameSize]; }


	// create engine
	slCreateEngine(&m_objEngine, 0, nullptr, 0, nullptr, nullptr);
	// realize the engine
	(*m_objEngine)->Realize(m_objEngine, SL_BOOLEAN_FALSE);
	// get the engine interface, which is needed in order to create other objects
	(*m_objEngine)->GetInterface(m_objEngine, SL_IID_ENGINE, &m_engine);

	// configure audio source
	SLDataLocator_IODevice loc_dev = {SL_DATALOCATOR_IODEVICE, SL_IODEVICE_AUDIOINPUT,
			SL_DEFAULTDEVICEID_AUDIOINPUT, NULL};
	SLDataSource audioSrc = {&loc_dev, NULL};

	// configure audio sink
	SLDataLocator_AndroidSimpleBufferQueue loc_bq = {SL_DATALOCATOR_ANDROIDSIMPLEBUFFERQUEUE, static_cast<unsigned int>(m_noBuffer)};
	SLDataFormat_PCM format_pcm = {SL_DATAFORMAT_PCM, 1, SL_SAMPLINGRATE_44_1,
		SL_PCMSAMPLEFORMAT_FIXED_16, SL_PCMSAMPLEFORMAT_FIXED_16,
		SL_SPEAKER_FRONT_CENTER, SL_BYTEORDER_LITTLEENDIAN};
	SLDataSink audioSnk = {&loc_bq, &format_pcm};

	// create audio recorder
	// (requires the RECORD_AUDIO permission)
	const SLInterfaceID id[2] = {SL_IID_ANDROIDSIMPLEBUFFERQUEUE, SL_IID_ANDROIDCONFIGURATION};
	const SLboolean req[2] = {SL_BOOLEAN_TRUE, SL_BOOLEAN_TRUE};
	(*m_engine)->CreateAudioRecorder(m_engine, &m_objRecorder, &audioSrc, &audioSnk, 2, id, req);

	SLAndroidConfigurationItf recorderConfig;
	SLint32 streamType = SL_ANDROID_RECORDING_PRESET_CAMCORDER;
	(*m_objRecorder)->GetInterface(m_objRecorder, SL_IID_ANDROIDCONFIGURATION, &recorderConfig);
	(*recorderConfig)->SetConfiguration(recorderConfig, SL_ANDROID_KEY_RECORDING_PRESET, &streamType, sizeof(SLint32));

	// realize the audio recorder
	(*m_objRecorder)->Realize(m_objRecorder, SL_BOOLEAN_FALSE);

	// get the record interface
	(*m_objRecorder)->GetInterface(m_objRecorder, SL_IID_RECORD, &m_recorder);

	// get the buffer queue interface
	(*m_objRecorder)->GetInterface(m_objRecorder, SL_IID_ANDROIDSIMPLEBUFFERQUEUE,
			&m_bufferQueue);

	// register callback on the buffer queue
	(*m_bufferQueue)->RegisterCallback(m_bufferQueue, recorderCallback, this);

	//Enqueue Buffer
	for(int i=0; i<m_noBuffer; ++i)
	{
		(*m_bufferQueue)->Enqueue(m_bufferQueue, m_buffer[i], m_frameByteSize);
	}
};

AudioInputAccessor::~AudioInputAccessor()
{
	// destroy audio recorder object, and invalidate all associated interfaces
	if (m_objRecorder != nullptr) {
		(*m_objRecorder)->Destroy(m_objRecorder);
		m_objRecorder = nullptr;
		m_recorder = nullptr;
		m_bufferQueue = nullptr;
	}
	// destroy engine object, and invalidate all associated interfaces
	if (m_objEngine != nullptr) {
		(*m_objEngine)->Destroy(m_objEngine);
		m_objEngine = nullptr;
		m_engine = nullptr;
	}

	for(int i=0; i<m_noBuffer; ++i)
	{ delete [] m_buffer[i]; }
	delete [] m_buffer;
	delete [] m_floatBuffer;
};

void AudioInputAccessor::startAudioInput()
{
	(*m_recorder)->SetRecordState(m_recorder, SL_RECORDSTATE_RECORDING);
};
void AudioInputAccessor::stopAudioInput()
{
	(*m_recorder)->SetRecordState(m_recorder, SL_RECORDSTATE_STOPPED);
};

void AudioInputAccessor::newInputBuffer()
{
	//recorderBuffer[currentbuffer] contains (the lastly filled) buffer data
	//do correlation check, decoding, or whatsoever with this array BEFORE enqueueing
    TapirDSP::vflt16(m_buffer[m_curBufferIdx], m_floatBuffer, m_frameSize);
    TapirDSP::vsdiv(m_floatBuffer, &kShortMax, m_floatBuffer, m_frameSize);
    m_detector->detect(m_floatBuffer);

	(*m_bufferQueue)->Enqueue(m_bufferQueue, m_buffer[m_curBufferIdx], m_frameByteSize);
	if((++m_curBufferIdx) >= m_noBuffer) { m_curBufferIdx = 0;}

};
