# Kaiju Engine prebuilt libraries
This repository is meant to be a submodule for the Kaiju game engine ([src/libs](https://github.com/KaijuEngine/kaiju/tree/master/src/libs) folder). It is to make it easier for developers to just get started compiling the engine and not mangaling dependencies. If you wish to compile the dependencies yourself, please follow the instructions below and copy the library files (and make sure their names match whats in this repository exactly) into the `src/libs` folder of the engine.

## Building Soloud
Currently the engine uses Soloud for playing music and sound effects. Below are instructions on how to build the library for the engine.

### Soloud Windows
```sh
git clone https://github.com/jarikomppa/soloud.git
cd soloud
cd contrib
mkdir build
cd build
cmake .. -G "MinGW Makefiles" .. -DSOLOUD_BACKEND_SDL2=OFF -DSOLOUD_BACKEND_WASAPI=ON -DSOLOUD_C_API=ON
cmake --build . --config Release
```

### Soloud Linux
```sh
git clone https://github.com/jarikomppa/soloud.git
cd soloud
cd contrib
mkdir build
cd build
cmake .. -G "Unix Makefiles" -DSOLOUD_BACKEND_SDL2=OFF -DSOLOUD_BACKEND_ALSA=ON -DSOLOUD_C_API=ON
cmake --build . --config Release
```

### Soloud MacOS
```sh
git clone https://github.com/jarikomppa/soloud.git
cd soloud/contrib
mkdir build
cd build
cmake .. -G "Unix Makefiles" -DSOLOUD_BACKEND_SDL2=OFF -DSOLOUD_BACKEND_COREAUDIO=ON -DSOLOUD_C_API=ON -DSOLOUD_STATIC=ON -DCMAKE_POLICY_VERSION_MINIMUM=3.5
cmake --build . --config Release
# Copy the library to kaiju
cp build/libsoloud.a /path/to/kaiju/src/libs/libsoloud_darwin.a
```

### Soloud Android (on Windows)
```sh
git clone https://github.com/jarikomppa/soloud.git
cd soloud
cd contrib
mkdir build
cd build
cmake .. -G "MinGW Makefiles" .. -DCMAKE_TOOLCHAIN_FILE=%NDK_HOME%/build/cmake/android.toolchain.cmake -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-21 -DANDROID_STL=c++_static -DCMAKE_BUILD_TYPE=Release -DSOLLOUD_STATIC=1 -DSOLLOUD_BUILD_DEMOS=OFF -DSOLOUD_BACKEND_OPENSLES=ON -DSOLOUD_BACKEND_SDL2=OFF -DSOLOUD_C_API=ON -DSOLOUD_BACKEND_NULL=OFF -DSOLOUD_BACKEND_MINIAUDIO=OFF -DSOLOUD_BACKEND_WAVEOUT=OFF -DSOLOUD_BACKEND_XAUDIO2=OFF -DSOLOUD_BACKEND_WINMM=OFF -DSOLOUD_BACKEND_WASAPI=OFF -DSOLOUD_BACKEND_ALSA=OFF -DSOLOUD_BACKEND_COREAUDIO=OFF -DSOLOUD_BACKEND_OPENAL=OFF -DSOLOUD_WAV=ON -DSOLOUD_OGG=ON -DSOLOUD_MP3=ON -DSOLOUD_FLAC=OFF -DSOLOUD_OPUS=OFF -DSOLOUD_SPEECH=OFF -DSOLOUD_SFXR=OFF -DSOLOUD_AY=OFF -DSOLOUD_SID=OFF -DSOLOUD_VIC=OFF -DSOLOUD_TEDSID=OFF -DSOLOUD_MONOTONE=OFF -DSOLOUD_VIC=OFF -DSOLOUD_BASSBOOST=OFF -DSOLOUD_BIQUAD=OFF -DSOLOUD_DCREMOVAL=OFF -DSOLOUD_ECHO=OFF -DSOLOUD_FFT=OFF -DSOLOUD_FREEVERB=OFF -DSOLOUD_LOFI=OFF -DSOLOUD_WAVESHAPER=OFF
cmake --build . --config Release
```

