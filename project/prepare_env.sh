#!/usr/bin/env bash
set -xeuo pipefail

mkdir package

printf "\n Download Android SDK: \n"
mkdir "$ANDROID_HOME" .android \
    && cd "$ANDROID_HOME" \
    && curl -o sdk.zip $SDK_URL \
    && unzip sdk.zip \
    && rm sdk.zip
    
printf "\n SDK Manager license: \n"

/usr/bin/expect -c '
set timeout -1;
spawn '"${ANDROID_HOME}"'/tools/bin/sdkmanager --licenses --proxy=http --proxy_host=proxy.bf.unity3d.com --proxy_port=3128;
  expect {
    "y/N" { exp_send "y\r" ; exp_continue }
    eof
  }
'

printf "\n Install Android Build Tool and Libraries: \n" && \
$ANDROID_HOME/tools/bin/sdkmanager --update --proxy=http --proxy_host=proxy.bf.unity3d.com --proxy_port=3128 >/dev/null

$ANDROID_HOME/tools/bin/sdkmanager "build-tools;${ANDROID_BUILD_TOOLS_VERSION}" \
    "platforms;android-${ANDROID_VERSION}" \
    "platform-tools" \
    --proxy=http \
    --proxy_host=proxy.bf.unity3d.com\
    --proxy_port=3128 \
    >/dev/null

printf "\n Finished preparing environment \n"