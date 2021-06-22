# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

# Setup build environment
PROJ_ROOT=$(shell pwd)
TVM_ROOT=$(shell cd ../..; pwd)
USER_HOME=/home/v70786
HOS_ROOT=${USER_HOME}/hos/hos2.0
PKG_CXXFLAGS = -Wall -std=c++14 -O2 -fPIC
PKG_INCLUDES = \
	-I${TVM_ROOT}/src/runtime/runtime/includes/ \
	-I${TVM_ROOT}/src/runtime/runtime/src/includes/ \
	-I${TVM_ROOT}/src/relay/backend/contrib/tinykernel/kernels/includes/
PKG_CXXFLAGS += ${PKG_INCLUDES}

PKG_LDFLAGS =-lm -ldl
build_dir := ${PROJ_ROOT}/build

deploy_x86: SET_BUILD_TARGET_X86 $(build_dir)/deploy_main
	$(build_dir)/deploy_main

deploy_android: SET_BUILD_TARGET_ANDROID $(build_dir)/deploy_main
	adb push $(build_dir)/deploy_main /data/local/tmp/
	adb shell chmod +x /data/local/tmp/deploy_main
	adb shell /data/local/tmp/deploy_main

deploy_x86_tvm: SET_BUILD_TARGET_X86_TVM $(build_dir)/deploy_main
	$(build_dir)/deploy_main

deploy_android_tvm: SET_BUILD_TARGET_ANDROID_TVM $(build_dir)/deploy_main
	adb push $(build_dir)/deploy_main /data/local/tmp/
	adb shell chmod +x /data/local/tmp/deploy_main
	adb shell /data/local/tmp/deploy_main

hmos_example_tiny:SET_BUILD_TARGET_TINYAI_HMOS $(build_dir)/libtinyruntime.a ${build_dir}/libmodelkernel.a
	$(eval EXAMPLE_DIR=ai_person_detection_tiny)
	@mkdir -p ${EXAMPLE_DIR}
	cp -r demo_main.cc ${EXAMPLE_DIR}/
	cp -r $(build_dir)/libtinyruntime.a ${EXAMPLE_DIR}/
	cp -r ${build_dir}/libmodelkernel.a ${EXAMPLE_DIR}/
	rm -rf $(build_dir)

hmos_example_tvm:SET_BUILD_TARGET_TVMAI_HMOS $(build_dir)/libtinyruntime.a ${build_dir}/libmodelkernel.a
	$(eval EXAMPLE_DIR=ai_face_detection_towards_tvm)
	@mkdir -p ${EXAMPLE_DIR}
	cp -r demo_main.cc ${EXAMPLE_DIR}/
	cp -r $(build_dir)/libtinyruntime.a ${EXAMPLE_DIR}/
	cp -r ${build_dir}/libmodelkernel.a ${EXAMPLE_DIR}/
	rm -rf $(build_dir)

SET_BUILD_TARGET_X86:
	$(eval BUILD_TARGET := 'llvm -system-lib')
	$(eval GPP_CC := g++)
	$(eval GPP_AR := ar)

SET_BUILD_TARGET_X86_TVM:
	$(eval TVMKERNEL := --tvmkernel)
	$(eval BUILD_TARGET := 'llvm -system-lib')
	$(eval GPP_CC := g++)
	$(eval GPP_AR := ar)

SET_BUILD_TARGET_ANDROID:
	$(eval BUILD_TARGET := 'llvm -system-lib')
	$(eval GPP_CC := /opt/android-toolchain/android-toolchain-arm64/bin/aarch64-linux-android-g++)
	$(eval GPP_AR := /opt/android-toolchain/android-toolchain-arm64/bin/aarch64-linux-android-ar)

SET_BUILD_TARGET_ANDROID_TVM:
	$(eval TVMKERNEL := --tvmkernel)
	$(eval BUILD_TARGET := 'llvm -system-lib -mtriple=aarch64-linux-android')
	$(eval GPP_CC := /opt/android-toolchain/android-toolchain-arm64/bin/aarch64-linux-android-g++)
	$(eval GPP_AR := /opt/android-toolchain/android-toolchain-arm64/bin/aarch64-linux-android-ar)

SET_BUILD_TARGET_TVMAI_HMOS:
	$(eval TVMKERNEL := --tvmkernel)
	$(eval BUILD_TARGET := 'llvm -system-lib -mtriple=arm-liteos -mcpu=cortex-a7 -mfloat-abi=soft')
	$(eval PKG_LDFLAGS := ${PKG_LDFLAGS})
	$(eval PKG_CXXFLAGS := -Wall -std=c++14 -O2 --target=arm-liteos -march=armv7-a -mfloat-abi=softfp -D__LITEOS__ -D__LITEOS_A__ -I${HOS_ROOT}/third_party/bounds_checking_function/include --sysroot=${HOS_ROOT}/prebuilts/lite/sysroot)
	$(eval PKG_CXXFLAGS = ${PKG_CXXFLAGS} ${PKG_INCLUDES})
	$(eval GPP_CC := ${USER_HOME}/llvm/bin/clang++)
	$(eval GPP_AR := arm-none-eabi-ar)

SET_BUILD_TARGET_TINYAI_HMOS:
	$(eval BUILD_TARGET := 'llvm -system-lib')
	$(eval PKG_LDFLAGS := ${PKG_LDFLAGS})
	$(eval PKG_CXXFLAGS := -Wall -std=c++14 -O2 --target=arm-liteos -march=armv7-a -mfloat-abi=softfp -D__LITEOS__ -D__LITEOS_A__ -I${HOS_ROOT}/third_party/bounds_checking_function/include --sysroot=${HOS_ROOT}/prebuilts/lite/sysroot)
	$(eval PKG_CXXFLAGS = ${PKG_CXXFLAGS} ${PKG_INCLUDES})
	$(eval GPP_CC := ${USER_HOME}/llvm/bin/clang++)
	$(eval GPP_AR := arm-none-eabi-ar)

$(build_dir)/deploy_main:demo_main.cc $(build_dir)/libtinyruntime.a $(build_dir)/libmodelkernel.a
	$(GPP_CC) $(PKG_CXXFLAGS) $(ADDITION_FLAG) -o $@ $^ $(PKG_LDFLAGS)

$(build_dir)/libmodelkernel.a $(build_dir)/libtinyruntime.a:
	@mkdir -p $(build_dir)
	/bin/bash ${TVM_ROOT}/tools/tinytvm_utility/prepare_model_artifacts.sh $(TVM_ROOT) $(build_dir) ${PROJ_ROOT}/model/face_detection_front.tflite $(BUILD_TARGET) "$(TVMKERNEL)" "$(GPP_CC)" "$(GPP_AR)" "$(PKG_CXXFLAGS)" "$(ADDITION_FLAG)"

clean:
	rm -rf $(build_dir)
