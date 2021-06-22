/*
 * Copyright (c) 2020 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#include <cstdint>
#include <ctime>
#include <limits>

#include "runtime.h"
static constexpr int kPersonIndex = 1;
static constexpr int kNotAPersonIndex = 2;

extern "C" void get_operator_funcs(std::vector<OHOS::AI::OperatorFunction>* operator_funcs);
extern const unsigned char params_ttk_bin[];
extern const unsigned char graph_ttk_flatbuffer[];
extern const unsigned char params_bin[];
extern const unsigned char graph_flatbuffer[];

uint32_t GetCurrentTime() {
  struct timespec time;
  clock_gettime(CLOCK_MONOTONIC, &time);
  return time.tv_sec * 1000 * 1000 + time.tv_nsec / 1000;  // us
}

class MemoryPoolManagerImpl : public OHOS::AI::MemoryPoolManager {
 public:
  void* AllocateMemoryPool(const size_t size) { return malloc(size); }

  void FreeMemoryPool(void* addr) { free(addr); }
};

int main(int argc, char* argv[]) {
  int itr_cnt = 100;
  if (argc == 2) {
    itr_cnt = atoi(argv[1]);
  }

  printf("model demo running on mcu using AI::Runtime\n");

  char* json_data = (char*)(graph_flatbuffer);
  char* params_data = (char*)(params_bin);

  uint32_t t0, t1, t2, t3, t4, t5;
  t0 = GetCurrentTime();

  std::vector<OHOS::AI::OperatorFunction> operatorFunctions;
  get_operator_funcs(&operatorFunctions);

  OHOS::AI::MemoryPoolManager* memoryPoolManager = new MemoryPoolManagerImpl();

  // Build an Runtime to run the model with.
  OHOS::AI::Runtime* runtime =
      new OHOS::AI::Runtime(json_data, params_data, &operatorFunctions, memoryPoolManager);
  t1 = GetCurrentTime();

  printf("Running for inference test data\n");
  float input_storage[1 * 128 * 128 * 3];
  for (int i = 0; i < 1 * 128 * 128 * 3; i++) {
    input_storage[i] = 0;
  }

  DLTensor input;
  input.data = input_storage;
  input.ndim = 4;
  DLDataType dtype = {kDLFloat, 32, 1};
  input.dtype = dtype;
  OHOS::AI::intcb_t shape[4] = {1, 128 , 128 , 3};
  input.shape = shape;

  runtime->SetInput("input", &input);
  t2 = GetCurrentTime();

  runtime->Run();
  t3 = GetCurrentTime();

  float output_storage[896*16];
  DLTensor output;
  output.data = output_storage;
  output.ndim = 3;
  DLDataType out_dtype = {kDLFloat, 32, 1};
  output.dtype = out_dtype;
  OHOS::AI::intcb_t out_shape[3] = {1, 896, 16};
  output.shape = out_shape;

  runtime->GetOutput(0, &output);
  t4 = GetCurrentTime();

  float max_iter = -std::numeric_limits<float>::max();
  int32_t max_index = -1;
  for (int i = 0; i <= 3; ++i) {
    printf("output_storage[%d]:%f\n", i, output_storage[i]);
    if (output_storage[i] > max_iter) {
      max_iter = output_storage[i];
      max_index = i;
    }
  }

  t5 = GetCurrentTime();

  printf(
      "The maximum position in output vector is: %d, with"
      " max-value %f.\n",
      max_index, max_iter);
  printf(
      "timing: %f us (create), %f us (set_input), %f us (run), "
      "%f us (get_output), %f us (destroy)\n",
      (t1 - t0) / 1.f, (t2 - t1) / 1.f, (t3 - t2) / 1.f, (t4 - t3) / 1.f, (t5 - t4) / 1.f);

  // printf("person data.  person score: %d, no person score: %d\n", output_storage[kPersonIndex],
  //        output_storage[kNotAPersonIndex]);

  if (itr_cnt > 0) {
    t0 = GetCurrentTime();
    for (int i = 0; i < itr_cnt; ++i) {
      for (int j = 0; j < 1 * 128 * 128 * 3; j++) {
        input_storage[j] = 127;
      }
      input.data = input_storage;
      runtime->SetInput("input", &input);
      runtime->Run();
      // output.data = output_storage;
      // runtime->GetOutput(0, &output);

      // max_iter = -std::numeric_limits<float>::max();
      // max_index = -1;
      // for (int j = 0; j < 3; ++j) {
      //   if (output_storage[j] > max_iter) {
      //     max_iter = output_storage[j];
      //     max_index = j;
      //   }
      // }
      // printf("%d iteration op max_val:%f max_val_position:%d",
      //    i, max_iter, max_index);
    }
    t1 = GetCurrentTime();

    printf("inference for %d run consume : %f us\n", itr_cnt, (t1 - t0) / 1.f / itr_cnt);
  }

  delete runtime;
  delete memoryPoolManager;
  return 0;
}
