#include <limits.h>
#include <stdint.h>
#include <stdlib.h>

#include <wasi/api.h>

#if defined(__WASI__) || defined(__wasi__)
#define ZEROPERL_COMMAND_EXPORT(name)                                          \
  __attribute__((export_name(name))) __attribute__((visibility("default")))
#else
#define ZEROPERL_COMMAND_EXPORT(name) __attribute__((visibility("default")))
#endif

int zeroperl_init_with_args(int argc, char **argv);

static int run_zeroperl(int argc, char **argv) {
  // Command modules are usually one-shot instances. Avoid running Perl global
  // teardown from _start because some browser/WASI shims trap during cleanup
  // after the script itself has completed.
  int status = zeroperl_init_with_args(argc, argv);
  return status;
}

static int run_zeroperl_with_wasi_args(void) {
  size_t argc = 0;
  size_t argv_buf_size = 0;

  if (__wasi_args_sizes_get(&argc, &argv_buf_size) != __WASI_ERRNO_SUCCESS ||
      argc > INT_MAX) {
    char *fallback_argv[] = {"zeroperl", "-e", "0", NULL};
    return run_zeroperl(3, fallback_argv);
  }

  char **argv = (char **)calloc(argc + 1, sizeof(char *));
  char *argv_buf = (char *)malloc(argv_buf_size ? argv_buf_size : 1);

  if (!argv || !argv_buf) {
    free(argv);
    free(argv_buf);
    return 1;
  }

  if (__wasi_args_get((uint8_t **)argv, (uint8_t *)argv_buf) !=
      __WASI_ERRNO_SUCCESS) {
    free(argv);
    free(argv_buf);
    return 1;
  }

  int status = run_zeroperl((int)argc, argv);
  free(argv);
  free(argv_buf);
  return status;
}

ZEROPERL_COMMAND_EXPORT("_start")
void zeroperl_command_start(void) {
  (void)run_zeroperl_with_wasi_args();
}

int main(int argc, char **argv) { return run_zeroperl(argc, argv); }
