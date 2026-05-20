#include <stdlib.h>

int zeroperl_init_with_args(int argc, char **argv);
void zeroperl_shutdown(void);

int main(int argc, char **argv) {
  int status = zeroperl_init_with_args(argc, argv);
  zeroperl_shutdown();
  return status;
}
