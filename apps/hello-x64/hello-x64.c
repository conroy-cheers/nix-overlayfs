#include <stdio.h>
#include <windows.h>

int main(void) {
  SYSTEM_INFO info;

  GetNativeSystemInfo(&info);

  printf("hello from windows x64\n");
  printf("pointer_bits=%u\n", (unsigned)(sizeof(void *) * 8));
  printf("native_arch=%u\n", (unsigned)info.wProcessorArchitecture);
  printf("pid=%lu\n", (unsigned long)GetCurrentProcessId());
  fflush(stdout);

  return 0;
}
