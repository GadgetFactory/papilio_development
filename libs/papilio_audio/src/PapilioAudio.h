/**
 * @file PapilioAudio.h
 * @brief Main header for Papilio Audio Library
 * 
 * Provides API for controlling retro sound chips (SID, YM2149, POKEY)
 * implemented in FPGA via Wishbone-over-SPI interface.
 * 
 * @author GadgetFactory
 * @license GPL-3.0
 */

#ifndef PAPILIO_AUDIO_H
#define PAPILIO_AUDIO_H

#include <Arduino.h>
#include <SPI.h>
#include "WishboneSPI.h"

// Include individual sound chip classes
#include "SID6581.h"
#include "YM2149.h"
#include "POKEY.h"
#include "AudioMixer.h"

// Default Wishbone base addresses for audio peripherals
#ifndef WB_AUDIO_SID_BASE
#define WB_AUDIO_SID_BASE     0x30   // SID chip: 0x30-0x4F (32 bytes)
#endif

#ifndef WB_AUDIO_YM2149_BASE
#define WB_AUDIO_YM2149_BASE  0x50   // YM2149: 0x50-0x5F (16 bytes)
#endif

#ifndef WB_AUDIO_POKEY_BASE
#define WB_AUDIO_POKEY_BASE   0x60   // POKEY: 0x60-0x6F (16 bytes)
#endif

#ifndef WB_AUDIO_MIXER_BASE
#define WB_AUDIO_MIXER_BASE   0x70   // Audio mixer: 0x70-0x7F (16 bytes)
#endif

#endif // PAPILIO_AUDIO_H
