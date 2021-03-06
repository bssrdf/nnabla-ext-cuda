# Copyright (c) 2017 Sony Corporation. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

########################################################################################################################
# Suppress most of make message.
.SILENT:

########################################################################################################################
# Settings

NNABLA_DIRECTORY ?= $(shell cd ../nnabla && pwd)
DOCKER_RUN_OPTS += -e NNABLA_DIRECTORY=$(NNABLA_DIRECTORY)

NNABLA_EXT_CUDA_DIRECTORY ?= $(shell pwd)
DOCKER_RUN_OPTS += -e NNABLA_EXT_CUDA_DIRECTORY=$(NNABLA_EXT_CUDA_DIRECTORY)
DOCKER_RUN_OPTS += -e CMAKE_OPTS=$(CMAKE_OPTS)

include $(NNABLA_EXT_CUDA_DIRECTORY)/build-tools/make/options.mk
ifndef NNABLA_BUILD_INCLUDED
  include $(NNABLA_DIRECTORY)/build-tools/make/build.mk
endif

ifndef NNABLA_BUILD_WITH_DOCKER_INCLUDED
  include $(NNABLA_DIRECTORY)/build-tools/make/build-with-docker.mk
endif

DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA ?= $(DOCKER_IMAGE_NAME_BASE)-build-cuda$(CUDA_VERSION_MAJOR)$(CUDA_VERSION_MINOR)-cudnn$(CUDNN_VERSION)
DOCKER_IMAGE_NNABLA_EXT_CUDA ?= $(DOCKER_IMAGE_NAME_BASE)-nnabla-ext--cuda$(CUDA_VERSION_MAJOR)$(CUDA_VERSION_MINOR)-cudnn$(CUDNN_VERSION)

DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA_MULTI_GPU ?= $(DOCKER_IMAGE_NAME_BASE)-build-cuda$(CUDA_VERSION_MAJOR)$(CUDA_VERSION_MINOR)-multi-gpu
DOCKER_IMAGE_NNABLA_EXT_CUDA_MULTI_GPU ?= $(DOCKER_IMAGE_NAME_BASE)-nnabla-ext-cuda$(CUDA_VERSION_MAJOR)$(CUDA_VERSION_MINOR)-multi-gpu


########################################################################################################################
# Docker image

DOCKERFILE_NAME_SUFFIX := py$(PYTHON_VERSION_MAJOR)$(PYTHON_VERSION_MINOR)
DOCKERFILE_NAME_SUFFIX := $(DOCKERFILE_NAME_SUFFIX)-cuda$(CUDA_VERSION_MAJOR)$(CUDA_VERSION_MINOR)
DOCKERFILE_NAME_SUFFIX := $(DOCKERFILE_NAME_SUFFIX)-cudnn$(CUDNN_VERSION)

DOCKER_IMAGE_BUILD_CUDA_BASE ?= nvidia/cuda:$(CUDA_VERSION_MAJOR).$(CUDA_VERSION_MINOR)-cudnn$(CUDNN_VERSION)-devel-centos6

DOCKER_IMAGE_BUILD_CUDA_MULTI_GPU_BASE ?= nvidia/cuda:$(CUDA_VERSION_MAJOR).$(CUDA_VERSION_MINOR)-cudnn$(CUDNN_VERSION)-devel-ubuntu16.04

.PHONY: docker_image_build_cuda
docker_image_build_cuda:
	docker pull $(DOCKER_IMAGE_BUILD_CUDA_BASE)
	@cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& docker build $(DOCKER_BUILD_ARGS)\
		--build-arg BASE=$(DOCKER_IMAGE_BUILD_CUDA_BASE) \
		-t $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA) \
		-f docker/development/Dockerfile.build \
		.

.PHONY: docker_image_build_cuda_multi_gpu
docker_image_build_cuda_multi_gpu:
	docker pull $(DOCKER_IMAGE_BUILD_CUDA_MULTI_GPU_BASE)
	@cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& docker build $(DOCKER_BUILD_ARGS) \
	             --build-arg BASE=$(DOCKER_IMAGE_BUILD_CUDA_MULTI_GPU_BASE) \
               -t $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA_MULTI_GPU) \
               -f docker/development/Dockerfile.build-multi-gpu \
               .

##############################################################################
# Auto Format

.PHONY: bwd-nnabla-ext-cuda-auto-format
bwd-nnabla-ext-cuda-auto-format: docker_image_auto_format
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& docker run $(DOCKER_RUN_OPTS) $(DOCKER_IMAGE_AUTO_FORMAT) make -f build-tools/make/build.mk nnabla-ext-cuda-auto-format

########################################################################################################################
# Build and test

NNABLA_DIRECTORY_ABSOLUTE = $(shell cd $(NNABLA_DIRECTORY) && pwd)
DOCKER_RUN_OPTS += -v $(NNABLA_DIRECTORY_ABSOLUTE):$(NNABLA_DIRECTORY_ABSOLUTE)

NNABLA_EXT_CUDA_DIRECTORY_ABSOLUTE = $(shell cd $(NNABLA_EXT_CUDA_DIRECTORY) && pwd)
DOCKER_RUN_OPTS += -v $(NNABLA_EXT_CUDA_DIRECTORY_ABSOLUTE):$(NNABLA_EXT_CUDA_DIRECTORY_ABSOLUTE)

.PHONY: bwd-nnabla-ext-cuda-cpplib
bwd-nnabla-ext-cuda-cpplib: docker_image_build_cuda
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& docker run $(DOCKER_RUN_OPTS) $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA) make -f build-tools/make/build.mk nnabla-ext-cuda-cpplib

.PHONY: bwd-nnabla-ext-cuda-wheel
bwd-nnabla-ext-cuda-wheel: docker_image_build_cuda
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& docker run $(DOCKER_RUN_OPTS) $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA) make -f build-tools/make/build.mk MAKE_MANYLINUX_WHEEL=ON nnabla-ext-cuda-wheel-local

.PHONY: bwd-nnabla-ext-cuda-wheel-multi-gpu
bwd-nnabla-ext-cuda-wheel-multi-gpu: docker_image_build_cuda_multi_gpu
	mkdir -p ~/.ccache
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& docker run $(DOCKER_RUN_OPTS) $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA_MULTI_GPU) make -f build-tools/make/build.mk nnabla-ext-cuda-wheel-multi-gpu

.PHONY: bwd-nnabla-ext-cuda-test
bwd-nnabla-ext-cuda-test: docker_image_build_cuda
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& nvidia-docker run $(DOCKER_RUN_OPTS) $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA) make -f build-tools/make/build.mk nnabla-ext-cuda-test-local

.PHONY: bwd-nnabla-ext-cuda-multi-gpu-test
bwd-nnabla-ext-cuda-multi-gpu-test: docker_image_build_cuda_multi_gpu
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& nvidia-docker run $(DOCKER_RUN_OPTS) $(DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA_MULTI_GPU) make -f build-tools/make/build.mk nnabla-ext-cuda-multi-gpu-test-local

.PHONY: bwd-nnabla-ext-cuda-shell
bwd-nnabla-ext-cuda-shell: docker_image_build_cuda
	cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& nvidia-docker run $(DOCKER_RUN_OPTS) -it --rm ${DOCKER_IMAGE_BUILD_NNABLA_EXT_CUDA} make nnabla-ext-cuda-shell

########################################################################################################################
# Docker image with current nnabla
.PHONY: docker_image_nnabla_ext_cuda
docker_image_nnabla_ext_cuda:
	BASE=nvidia/cuda:$(CUDA_VERSION_MAJOR).$(CUDA_VERSION_MINOR)-cudnn$(CUDNN_VERSION)-runtime-ubuntu16.04 \
	&& docker pull $${BASE} \
	&& cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& cp docker/runtime/Dockerfile.runtime Dockerfile \
	&& cp $(BUILD_DIRECTORY_WHEEL)/dist/*.whl . \
	&& echo ADD $(shell basename $(BUILD_DIRECTORY_WHEEL)/dist/*.whl) /tmp/ >>Dockerfile \
	&& echo RUN pip install /tmp/$(shell basename $(BUILD_DIRECTORY_WHEEL)/dist/*.whl) >>Dockerfile \
	&& cp $(BUILD_EXT_CUDA_DIRECTORY_WHEEL)/dist/*.whl . \
	&& echo ADD $(shell basename $(BUILD_EXT_CUDA_DIRECTORY_WHEEL)/dist/*.whl) /tmp/ >>Dockerfile \
	&& echo RUN pip install /tmp/$(shell basename $(BUILD_EXT_CUDA_DIRECTORY_WHEEL)/dist/*.whl) >>Dockerfile \
	&& docker build --build-arg BASE=$${BASE} $(DOCKER_BUILD_ARGS) -t $(DOCKER_IMAGE_NNABLA_EXT_CUDA) . \
	&& rm -f $(shell basename $(BUILD_DIRECTORY_WHEEL)/dist/*.whl) \
	&& rm -f $(shell basename $(BUILD_EXT_CUDA_DIRECTORY_WHEEL_MULTI_GPU)/dist/*.whl) \
	&& rm -f Dockerfile

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu
docker_image_nnabla_ext_cuda_multi_gpu: bwd-nnabla-ext-cuda-wheel-multi-gpu
	mkdir -p ~/.ccache
	BASE=nvidia/cuda:$(CUDA_VERSION_MAJOR).$(CUDA_VERSION_MINOR)-cudnn$(CUDNN_VERSION)-runtime-ubuntu16.04 \
	&& docker pull $${BASE} \
	&& cd $(NNABLA_EXT_CUDA_DIRECTORY) \
	&& cp docker/runtime/Dockerfile.runtime-multi-gpu Dockerfile \
	&& cp $(BUILD_DIRECTORY_WHEEL)/dist/*.whl . \
	&& echo ADD $(shell basename $(BUILD_DIRECTORY_WHEEL)/dist/*.whl) /tmp/ >>Dockerfile \
	&& echo RUN pip install /tmp/$(shell basename $(BUILD_DIRECTORY_WHEEL)/dist/*.whl) >>Dockerfile \
	&& cp $(BUILD_EXT_CUDA_DIRECTORY_WHEEL_MULTI_GPU)/dist/*.whl . \
	&& echo ADD $(shell basename $(BUILD_EXT_CUDA_DIRECTORY_WHEEL_MULTI_GPU)/dist/*.whl) /tmp/ >>Dockerfile \
	&& echo RUN pip install /tmp/$(shell basename $(BUILD_EXT_CUDA_DIRECTORY_WHEEL_MULTI_GPU)/dist/*.whl) >>Dockerfile \
	&& docker build --build-arg BASE=$${BASE} $(DOCKER_BUILD_ARGS) -t $(DOCKER_IMAGE_NNABLA_EXT_CUDA_MULTI_GPU) . \
	&& rm -f $(shell basename $(BUILD_DIRECTORY_WHEEL)/dist/*.whl) \
	&& rm -f $(shell basename $(BUILD_EXT_CUDA_DIRECTORY_WHEEL_MULTI_GPU)/dist/*.whl) \
	&& rm -f Dockerfile


.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda90
docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda90:
	docker pull nvidia/cuda:9.0-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py35-cuda90 \
		-f nnabla-ext-cuda/docker/py35/cuda90-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda92
docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda92:
	docker pull nvidia/cuda:9.2-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py35-cuda92 \
		-f nnabla-ext-cuda/docker/py35/cuda92-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda100
docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda100:
	docker pull nvidia/cuda:10.0-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py35-cuda100 \
		-f nnabla-ext-cuda/docker/py35/cuda100-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda90
docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda90:
	docker pull nvidia/cuda:9.0-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py36-cuda90 \
		-f nnabla-ext-cuda/docker/py36/cuda90-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda92
docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda92:
	docker pull nvidia/cuda:9.2-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py36-cuda92 \
		-f nnabla-ext-cuda/docker/py36/cuda92-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda100
docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda100:
	docker pull nvidia/cuda:10.0-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py36-cuda100 \
		-f nnabla-ext-cuda/docker/py36/cuda100-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda90
docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda90:
	docker pull nvidia/cuda:9.0-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py37-cuda90 \
		-f nnabla-ext-cuda/docker/py37/cuda90-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda92
docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda92:
	docker pull nvidia/cuda:9.2-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py37-cuda92 \
		-f nnabla-ext-cuda/docker/py37/cuda92-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda100
docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda100:
	docker pull nvidia/cuda:10.0-cudnn7-runtime-ubuntu16.04
	docker build --build-arg http_proxy=${http_proxy} --build-arg https_proxy=${https_proxy} \
		-t $(DOCKER_IMAGE_NAME_BASE)-multi-gpu-py37-cuda100 \
		-f nnabla-ext-cuda/docker/py37/cuda100-multi-gpu/Dockerfile .

.PHONY: docker_image_nnabla_ext_cuda_multi_gpu_all
docker_image_nnabla_ext_cuda_multi_gpu_all: \
	docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda90 \
	docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda92 \
	docker_image_nnabla_ext_cuda_multi_gpu_py35_cuda100 \
	docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda90 \
	docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda92 \
	docker_image_nnabla_ext_cuda_multi_gpu_py36_cuda100 \
	docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda90 \
	docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda92 \
	docker_image_nnabla_ext_cuda_multi_gpu_py37_cuda100
