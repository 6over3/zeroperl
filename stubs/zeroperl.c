#define PERL_IN_MINIPERLMAIN_C

#include "zeroperl.h" /* Must define SFS_BUILTIN_PREFIX, e.g. "builtin:" */
#include "EXTERN.h"
#include "XSUB.h"
#include "asyncify.h"
#include "perl.h"
#include "setjmp.h"
#include <assert.h>
#include <errno.h>
#include <fcntl.h>
#include <locale.h>
#include <stdarg.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

// Compatibility: av_top_index was added in 5.18, older Perl uses av_len
#ifndef av_top_index
#define av_top_index(av) av_len(av)
#endif

#define STRINGIZE_HELPER(x) #x
#define STRINGIZE(x) STRINGIZE_HELPER(x)
#include <wasi/api.h>

#include "sfs_runtime.h"

//! Export macro for public API functions - combines export_name for WASI with
//! visibility attribute
#if defined(__WASI__) || defined(__wasi__)
#define ZEROPERL_API(name)                                                     \
  __attribute__((export_name(name))) __attribute__((visibility("default")))
#define ZEROPERL_IMPORT(name)                                                  \
  __attribute__((import_module("env"))) __attribute__((import_name(name)))
#else
#define ZEROPERL_API(name) __attribute__((visibility("default")))
#define ZEROPERL_IMPORT(name)
#endif

//! Writes the given string literal directly to STDERR via __wasi_fd_write
//! Avoids calls to printf or other asyncified C library functions
#define DEBUG_LOG_INTERNAL(msg)                                                \
  do {                                                                         \
    const uint8_t *msg_start = (const uint8_t *)(msg);                         \
    const uint8_t *msg_end = msg_start;                                        \
    while (*msg_end != '\0') {                                                 \
      msg_end++;                                                               \
    }                                                                          \
    __wasi_ciovec_t iov = {.buf = msg_start,                                   \
                           .buf_len = (size_t)(msg_end - msg_start)};          \
    size_t nwritten;                                                           \
    __wasi_fd_write(STDERR_FILENO, &iov, 1, &nwritten);                        \
  } while (0)

//! Appends file name and line number, then calls DEBUG_LOG_INTERNAL
#define DEBUG_LOG(msg)                                                         \
  DEBUG_LOG_INTERNAL(__FILE__ ":" STRINGIZE(__LINE__) ": " msg "\n")

//! Forward declaration for XS init function
static void xs_init(pTHX);

//! Global Perl interpreter instance
static PerlInterpreter *zero_perl = NULL;

//! Global state flags
static bool zero_perl_system_initialized = false; // PERL_SYS_INIT3 called
static bool zero_perl_can_evaluate = false; // perl_run called, ready for eval

//! Error message buffer (stores last Perl error from $@)
static char zero_perl_error_buf[1024] = {0};
//! Host error message buffer (stores last host error)
static char host_error_buf[1024] = {0};

#define ZEROPERL_EMBEDDED_LIB_PREFIX                                           \
  "/zeroperl/lib/" STRINGIZE(PERL_REVISION) "." STRINGIZE(PERL_VERSION) "."    \
      STRINGIZE(PERL_SUBVERSION)
#define ZEROPERL_EMBEDDED_ARCH_LIB ZEROPERL_EMBEDDED_LIB_PREFIX "/wasm32-wasi"

#ifndef ZEROPERL_PERL5LIB_MAX
#define ZEROPERL_PERL5LIB_MAX 4096
#endif

//! Environment variables
extern char **environ;

//! External declarations for the underlying ("real") syscalls (wrapped via
//! linker)
extern FILE *__real_fopen(const char *path, const char *mode);
extern int __real_fileno(FILE *stream);
extern int __real_open(const char *path, int flags, ...);
extern int __real_close(int fd);
extern ssize_t __real_read(int fd, void *buf, size_t count);
extern off_t __real_lseek(int fd, off_t offset, int whence);
extern int __real_access(const char *path, int flags);
extern int __real_stat(const char *restrict path,
                       struct stat *restrict statbuf);
extern int __real_fstat(int fd, struct stat *statbuf);

static SfsRuntime sfs_runtime;
static bool sfs_runtime_initialized = false;

static inline void sfs_runtime_ensure_initialized(void) {
  if (!sfs_runtime_initialized) {
    sfs_runtime_init(&sfs_runtime, SFS_BUILTIN_PREFIX);
    sfs_runtime_initialized = true;
  }
}


//! Wrapper for fopen: tries SFS first, then falls back to real fopen
__attribute__((noinline)) FILE *__wrap_fopen(const char *path,
                                             const char *mode) {
  sfs_runtime_ensure_initialized();
  if (sfs_runtime_has_prefix(&sfs_runtime, path)) {
    FILE *fp = NULL;
    int sfd = sfs_runtime_open(&sfs_runtime, sfs_entries, sfs_builtin_files_num,
                               path, &fp);
    if (sfd >= 0) {
      return fp;
    }
    /* SFS doesn't have this file; fall through to real filesystem. */
  }

  FILE *realfp = __real_fopen(path, mode);
  if (realfp) {
    int realfd = fileno(realfp);
    sfs_runtime_mark_fd_in_use(&sfs_runtime, realfd);
  }
  return realfp;
}

//! Wrapper for open: tries SFS first, then falls back to real open
__attribute__((noinline)) int __wrap_open(const char *path, int flags, ...) {
  sfs_runtime_ensure_initialized();
  va_list args;
  va_start(args, flags);
  int mode = 0;
  if (flags & O_CREAT) {
    mode = va_arg(args, int);
  }
  va_end(args);

  if (sfs_runtime_has_prefix(&sfs_runtime, path)) {
    int sfd = sfs_runtime_open(&sfs_runtime, sfs_entries, sfs_builtin_files_num,
                               path, NULL);
    if (sfd >= 0) {
      return sfd;
    }
    /* SFS doesn't have this file; fall through to real filesystem. */
  }

  int realfd = __real_open(path, flags, mode);
  sfs_runtime_mark_fd_in_use(&sfs_runtime, realfd);
  return realfd;
}

//! Wrapper for close: tries SFS first, then falls back to real close
__attribute__((noinline)) int __wrap_close(int fd) {
  sfs_runtime_ensure_initialized();
  SFS_Result rc = sfs_runtime_close(&sfs_runtime, fd);
  if (rc == SFS_OK) {
    return 0;
  }
  if (rc == SFS_NOT_OURS) {
    sfs_runtime_mark_fd_free(&sfs_runtime, fd);
    return __real_close(fd);
  }
  return (int)rc;
}

//! Wrapper for access: tries SFS first, then falls back to real access
__attribute__((noinline)) int __wrap_access(const char *path, int amode) {
  sfs_runtime_ensure_initialized();
  if (sfs_runtime_has_prefix(&sfs_runtime, path)) {
    int rc = sfs_runtime_access(&sfs_runtime, sfs_entries, sfs_builtin_files_num,
                                path);
    if (rc == 0) {
      return 0;
    }
    /* SFS doesn't have this path; fall through to real filesystem. */
  }
  return __real_access(path, amode);
}

//! Wrapper for stat: tries SFS first, then falls back to real stat
__attribute__((noinline)) int __wrap_stat(const char *restrict path,
                                          struct stat *restrict stbuf) {
  sfs_runtime_ensure_initialized();
  SFS_Stat_Result rc = sfs_runtime_stat(&sfs_runtime, sfs_entries,
                                        sfs_builtin_files_num, path, -1, stbuf);
  if (rc == SFS_STAT_OURS) {
    return 0;
  }
  /* SFS_STAT_ERR: path has SFS prefix but file not in SFS; fall through. */
  return __real_stat(path, stbuf);
}

//! Wrapper for fstat: tries SFS first, then falls back to real fstat
__attribute__((noinline)) int __wrap_fstat(int fd, struct stat *stbuf) {
  sfs_runtime_ensure_initialized();
  SFS_Stat_Result rc = sfs_runtime_stat(&sfs_runtime, sfs_entries,
                                        sfs_builtin_files_num, NULL, fd, stbuf);
  if (rc == SFS_STAT_OURS) {
    return 0;
  }
  /* SFS_STAT_ERR or SFS_STAT_NOT_OURS: fall through to real fstat. */
  return __real_fstat(fd, stbuf);
}

//! Wrapper for read: tries SFS first, then falls back to real read
__attribute__((noinline)) ssize_t __wrap_read(int fd, void *buf, size_t count) {
  sfs_runtime_ensure_initialized();
  ssize_t r = sfs_runtime_read(&sfs_runtime, fd, buf, count);
  if (r >= 0) {
    return r;
  }
  return __real_read(fd, buf, count);
}

//! Wrapper for lseek: tries SFS first, then falls back to real lseek
__attribute__((noinline)) off_t __wrap_lseek(int fd, off_t offset, int whence) {
  sfs_runtime_ensure_initialized();
  off_t pos = sfs_runtime_lseek(&sfs_runtime, fd, offset, whence);
  if (pos >= 0) {
    return pos;
  }
  return __real_lseek(fd, offset, whence);
}

//! Wrapper for fileno: checks SFS first, then falls back to real fileno
__attribute__((noinline)) int __wrap_fileno(FILE *stream) {
  sfs_runtime_ensure_initialized();
  int sfsfd = sfs_runtime_fileno(&sfs_runtime, stream);
  if (sfsfd >= 0) {
    return sfsfd;
  }

  int realfd = __real_fileno(stream);
  sfs_runtime_mark_fd_in_use(&sfs_runtime, realfd);
  return realfd;
}

//! Opaque handle to a Perl scalar value
typedef struct zeroperl_value_s {
  SV *sv;
} zeroperl_value;

//! Opaque handle to a Perl array
typedef struct zeroperl_array_s {
  AV *av;
} zeroperl_array;

//! Opaque handle to a Perl hash
typedef struct zeroperl_hash_s {
  HV *hv;
} zeroperl_hash;

//! Opaque handle to a Perl code reference
typedef struct zeroperl_code_s {
  CV *cv;
} zeroperl_code;

//! Result structure for operations that return multiple values
typedef struct zeroperl_result_s {
  int count;
  zeroperl_value **values;
} zeroperl_result;

//! Iterator for hash traversal
typedef struct zeroperl_hash_iter_s {
  HV *hv;
  HE *entry;
} zeroperl_hash_iter;

//! Context type for calling Perl code
typedef enum {
  ZEROPERL_VOID,
  ZEROPERL_SCALAR,
  ZEROPERL_LIST
} zeroperl_context_type;

//! Value type enumeration
typedef enum {
  ZEROPERL_TYPE_UNDEF,
  ZEROPERL_TYPE_TRUE,
  ZEROPERL_TYPE_FALSE,
  ZEROPERL_TYPE_INT,
  ZEROPERL_TYPE_DOUBLE,
  ZEROPERL_TYPE_STRING,
  ZEROPERL_TYPE_ARRAY,
  ZEROPERL_TYPE_HASH,
  ZEROPERL_TYPE_CODE,
  ZEROPERL_TYPE_REF
} zeroperl_type;

//! Operation type for unified context
typedef enum {
  ZEROPERL_OP_INIT,
  ZEROPERL_OP_EVAL,
  ZEROPERL_OP_RUN_FILE,
  ZEROPERL_OP_RESET,
  ZEROPERL_OP_CALL
} zeroperl_op_type;

//! Unified context structure for all Perl operations
typedef struct {
  zeroperl_op_type op_type;
  int result;
  union {
    struct {
      int argc;
      char **argv;
    } init;
    struct {
      const char *code;
      int argc;
      char **argv;
      zeroperl_context_type context;
    } eval;
    struct {
      const char *filepath;
      int argc;
      char **argv;
    } run_file;
    struct {
      const char *name;
      int argc;
      zeroperl_value **argv;
      zeroperl_context_type context;
    } call;
  } data;
} zeroperl_context;

//! Host-implemented function for calling back into the host environment
ZEROPERL_IMPORT("call_host_function")
zeroperl_value *host_call_function(int32_t func_id, int32_t argc,
                                   zeroperl_value **argv);

//! Registry for host function IDs
typedef struct {
  int32_t func_id;
  char *name;
  char *package;
  bool is_method;
} host_function_entry;

#ifndef MAX_HOST_FUNCTIONS
#define MAX_HOST_FUNCTIONS 256
#endif

static host_function_entry host_functions[MAX_HOST_FUNCTIONS];
static int host_function_count = 0;

//! Captures the current Perl error ($@) into the error buffer
static void zeroperl_capture_error(void) {
  zero_perl_error_buf[0] = '\0';

  if (!zero_perl)
    return;

  dTHX;
  SV *errsv = get_sv("@", 0);
  if (errsv && SvTRUE(errsv)) {
    const char *err = SvPV_nolen(errsv);
    if (err) {
      strncpy(zero_perl_error_buf, err, sizeof(zero_perl_error_buf) - 1);
      zero_perl_error_buf[sizeof(zero_perl_error_buf) - 1] = '\0';
    }
  }
}

//! Clears the Perl error variable ($@)
static void zeroperl_clear_error_internal(void) {
  if (!zero_perl)
    return;

  dTHX;
  sv_setpvn(ERRSV, "", 0);
}

ZEROPERL_API("zeroperl_set_host_error")
void zeroperl_set_host_error(const char *error) {
  if (error) {
    strncpy(host_error_buf, error, sizeof(host_error_buf) - 1);
    host_error_buf[sizeof(host_error_buf) - 1] = '\0';
  } else {
    host_error_buf[0] = '\0';
  }
}

ZEROPERL_API("zeroperl_get_host_error")
const char *zeroperl_get_host_error(void) { return host_error_buf; }

ZEROPERL_API("zeroperl_clear_host_error")
void zeroperl_clear_host_error(void) { host_error_buf[0] = '\0'; }

static bool zeroperl_env_list_contains_path(const char *list, const char *path) {
  if (!list || !path || path[0] == '\0') {
    return false;
  }

  size_t path_len = strlen(path);
  const char *segment = list;
  while (*segment != '\0') {
    const char *end = strchr(segment, ':');
    size_t len = end ? (size_t)(end - segment) : strlen(segment);
    if (len == path_len && strncmp(segment, path, path_len) == 0) {
      return true;
    }
    if (!end) {
      break;
    }
    segment = end + 1;
  }

  return false;
}

static int zeroperl_append_env_segment(char *dst, size_t dst_size, size_t *used,
                                       const char *segment) {
  if (!segment || segment[0] == '\0') {
    return 0;
  }

  size_t segment_len = strlen(segment);
  size_t required = *used + segment_len + 1;
  if (*used > 0) {
    required++;
  }
  if (required > dst_size) {
    errno = ENAMETOOLONG;
    return -1;
  }

  if (*used > 0) {
    dst[*used] = ':';
    (*used)++;
  }
  memcpy(dst + *used, segment, segment_len + 1);
  *used += segment_len;
  return 0;
}

static int zeroperl_prepare_embedded_perl5lib(void) {
  const char *existing = getenv("PERL5LIB");
  bool has_arch = zeroperl_env_list_contains_path(existing,
                                                  ZEROPERL_EMBEDDED_ARCH_LIB);
  bool has_lib = zeroperl_env_list_contains_path(existing,
                                                 ZEROPERL_EMBEDDED_LIB_PREFIX);
  if (has_arch && has_lib) {
    return 0;
  }

  char combined[ZEROPERL_PERL5LIB_MAX];
  size_t used = 0;
  combined[0] = '\0';

  // Native Perl precedence: existing PERL5LIB comes first, followed by the
  // embedded arch/lib paths.  This ensures user-supplied directories are
  // searched before the bundled libraries.
  if (existing && existing[0] != '\0' &&
      zeroperl_append_env_segment(combined, sizeof(combined), &used, existing) !=
          0) {
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "combined PERL5LIB exceeds %d bytes", ZEROPERL_PERL5LIB_MAX);
    return -1;
  }
  if (!has_arch &&
      zeroperl_append_env_segment(combined, sizeof(combined), &used,
                                  ZEROPERL_EMBEDDED_ARCH_LIB) != 0) {
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "embedded PERL5LIB entry too long: %s", ZEROPERL_EMBEDDED_ARCH_LIB);
    return -1;
  }
  if (!has_lib &&
      zeroperl_append_env_segment(combined, sizeof(combined), &used,
                                  ZEROPERL_EMBEDDED_LIB_PREFIX) != 0) {
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "embedded PERL5LIB entry too long: %s",
             ZEROPERL_EMBEDDED_LIB_PREFIX);
    return -1;
  }

  if (setenv("PERL5LIB", combined, 1) != 0) {
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "failed to set PERL5LIB: %s", strerror(errno));
    return -1;
  }

  return 0;
}

//! XS callback that dispatches to host functions
static XS(xs_host_dispatch) {
  dXSARGS;

  int32_t func_id = (int32_t)CvXSUBANY(cv).any_i32;

  zeroperl_clear_host_error();

  zeroperl_value **argv = NULL;
  if (items > 0) {
    argv = (zeroperl_value **)malloc(sizeof(zeroperl_value *) * items);
    for (int i = 0; i < items; i++) {
      argv[i] = (zeroperl_value *)malloc(sizeof(zeroperl_value));
      argv[i]->sv = ST(i);
      SvREFCNT_inc(argv[i]->sv);
    }
  }

  zeroperl_value *result = host_call_function(func_id, items, argv);

  if (argv) {
    for (int i = 0; i < items; i++) {
      SvREFCNT_dec(argv[i]->sv);
      free(argv[i]);
    }
    free(argv);
  }

  if (!result || !result->sv) {
    if (result) {
      free(result);
    }

    const char *host_err = zeroperl_get_host_error();
    if (host_err && host_err[0] != '\0') {
      croak("%s", host_err);
    }

    XSRETURN_UNDEF;
  }

  SV *sv = result->sv;
  SvREFCNT_inc(sv);
  free(result);
  ST(0) = sv_2mortal(sv);
  XSRETURN(1);
}

//! Internal callback for initialization
static int zeroperl_init_callback(int argc, char **argv) {
  (void)argc;
  zeroperl_context *ctx = (zeroperl_context *)argv;

  if (zeroperl_prepare_embedded_perl5lib() != 0) {
    ctx->result = 1;
    return 1;
  }

  if (!zero_perl_system_initialized) {
    PERL_SYS_INIT3(&ctx->data.init.argc, &ctx->data.init.argv, &environ);
#ifdef PERL_SYS_FPU_INIT
    PERL_SYS_FPU_INIT;
#endif
    zero_perl_system_initialized = true;
  }

  zero_perl = perl_alloc();
  if (!zero_perl) {
    ctx->result = 1;
    return 1;
  }

  perl_construct(zero_perl);

  PL_perl_destruct_level = 0;
  PL_exit_flags &= ~PERL_EXIT_DESTRUCT_END;

  if (ctx->data.init.argc > 0 && ctx->data.init.argv) {
    if (perl_parse(zero_perl, xs_init, ctx->data.init.argc, ctx->data.init.argv,
                   environ) != 0) {
      zeroperl_capture_error();
      ctx->result = 1;
      return 1;
    }
  } else {
    char *minimal_argv[] = {"", "-e", "0", NULL};
    if (perl_parse(zero_perl, xs_init, 3, minimal_argv, environ) != 0) {
      zeroperl_capture_error();
      ctx->result = 1;
      return 1;
    }
  }

  int run_result = perl_run(zero_perl);
  if (run_result != 0) {
    zeroperl_capture_error();
    ctx->result = run_result;
    return run_result;
  }

  zero_perl_can_evaluate = true;
  ctx->result = 0;
  return 0;
}

//! Internal callback for evaluation
static int zeroperl_eval_callback(int argc, char **argv) {
  (void)argc;
  zeroperl_context *ctx = (zeroperl_context *)argv;

  if (!zero_perl || !zero_perl_can_evaluate) {
    ctx->result = -1;
    return -1;
  }

  zeroperl_clear_error_internal();

  dTHX;
  dSP;

  ENTER;
  SAVETMPS;

  if (ctx->data.eval.argc > 0 && ctx->data.eval.argv) {
    AV *argv_av = get_av("ARGV", GV_ADD);
    av_clear(argv_av);
    for (int i = 0; i < ctx->data.eval.argc; i++) {
      av_push(argv_av, newSVpv(ctx->data.eval.argv[i], 0));
    }
  }

  I32 gimme;
  switch (ctx->data.eval.context) {
  case ZEROPERL_VOID:
    gimme = G_VOID;
    break;
  case ZEROPERL_LIST:
    gimme = G_ARRAY;
    break;
  case ZEROPERL_SCALAR:
  default:
    gimme = G_SCALAR;
    break;
  }

  SV *result = eval_pv(ctx->data.eval.code, FALSE);

  if (SvTRUE(ERRSV)) {
    zeroperl_capture_error();
    ctx->result = -1;
  } else {
    ctx->result = 0;
  }

  FREETMPS;
  LEAVE;

  return ctx->result;
}

//! Internal callback for running a file
static int zeroperl_run_file_callback(int argc, char **argv) {
  (void)argc;
  zeroperl_context *ctx = (zeroperl_context *)argv;

  if (!zero_perl || !zero_perl_can_evaluate) {
    ctx->result = 1;
    return 1;
  }

  const char *filepath = ctx->data.run_file.filepath;

  if (access(filepath, R_OK) != 0) {
    if (access(filepath, F_OK) != 0) {
      snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
               "Can't open perl script \"%s\": No such file or directory",
               filepath);
    } else {
      snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
               "Can't open perl script \"%s\": Permission denied", filepath);
    }
    ctx->result = 1;
    return 1;
  }

  zeroperl_clear_error_internal();

  dTHX;

  FILE *fp = fopen(filepath, "r");
  if (!fp) {
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "Can't open perl script \"%s\": %s", filepath, strerror(errno));
    ctx->result = 1;
    return 1;
  }

  if (fseek(fp, 0, SEEK_END) != 0) {
    fclose(fp);
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "Can't seek in perl script \"%s\": %s", filepath, strerror(errno));
    ctx->result = 1;
    return 1;
  }

  long file_size = ftell(fp);
  if (file_size < 0) {
    fclose(fp);
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "Can't determine size of perl script \"%s\"", filepath);
    ctx->result = 1;
    return 1;
  }

  if (fseek(fp, 0, SEEK_SET) != 0) {
    fclose(fp);
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "Can't seek in perl script \"%s\": %s", filepath, strerror(errno));
    ctx->result = 1;
    return 1;
  }

  char *code = (char *)malloc((size_t)file_size + 1);
  if (!code) {
    fclose(fp);
    strncpy(zero_perl_error_buf, "Out of memory reading perl script",
            sizeof(zero_perl_error_buf) - 1);
    zero_perl_error_buf[sizeof(zero_perl_error_buf) - 1] = '\0';
    ctx->result = 1;
    return 1;
  }

  size_t bytes_read = fread(code, 1, (size_t)file_size, fp);
  int read_error = ferror(fp);
  fclose(fp);

  if (read_error) {
    free(code);
    snprintf(zero_perl_error_buf, sizeof(zero_perl_error_buf),
             "Error reading perl script \"%s\"", filepath);
    ctx->result = 1;
    return 1;
  }

  code[bytes_read] = '\0';

  dSP;
  ENTER;
  SAVETMPS;

  if (ctx->data.run_file.argc > 0 && ctx->data.run_file.argv) {
    AV *argv_av = get_av("ARGV", GV_ADD);
    av_clear(argv_av);
    for (int i = 0; i < ctx->data.run_file.argc; i++) {
      av_push(argv_av, newSVpv(ctx->data.run_file.argv[i], 0));
    }
  }

  sv_setpv(get_sv("0", GV_ADD), filepath);

  eval_pv(code, FALSE);

  free(code);

  if (SvTRUE(ERRSV)) {
    zeroperl_capture_error();
    ctx->result = -1;
  } else {
    ctx->result = 0;
  }

  FREETMPS;
  LEAVE;

  return ctx->result;
}

//! Internal callback for reset
static int zeroperl_reset_callback(int argc, char **argv) {
  (void)argc;
  zeroperl_context *ctx = (zeroperl_context *)argv;

  if (!zero_perl) {
    ctx->result = -1;
    return -1;
  }

  if (zeroperl_prepare_embedded_perl5lib() != 0) {
    ctx->result = 1;
    return 1;
  }

  perl_destruct(zero_perl);
  perl_construct(zero_perl);

  PL_perl_destruct_level = 0;
  PL_exit_flags &= ~PERL_EXIT_DESTRUCT_END;
  zero_perl_can_evaluate = false;

  // Reset opfreehook to prevent glob_ophook from chaining to itself
  // after interpreter reset (the static my_cxt in File::Glob retains
  // its old value across resets in non-MULTIPLICITY builds)
  PL_opfreehook = NULL;

  if (ctx->data.init.argc > 0 && ctx->data.init.argv) {
    if (perl_parse(zero_perl, xs_init, ctx->data.init.argc, ctx->data.init.argv,
                   environ) != 0) {
      zeroperl_capture_error();
      ctx->result = 1;
      return 1;
    }
  } else {
    char *minimal_argv[] = {"", "-e", "0", NULL};
    if (perl_parse(zero_perl, xs_init, 3, minimal_argv, environ) != 0) {
      zeroperl_capture_error();
      ctx->result = 1;
      return 1;
    }
  }

  int run_result = perl_run(zero_perl);
  if (run_result != 0) {
    zeroperl_capture_error();
    ctx->result = run_result;
    return run_result;
  }

  zero_perl_can_evaluate = true;
  ctx->result = 0;
  return 0;
}

//! Initialize the Perl interpreter
//!
//! Performs complete Perl system initialization and creates an interpreter
//! ready for interactive evaluation. After this function succeeds, you can
//! call zeroperl_eval() to evaluate Perl code.
//!
//! Returns 0 on success, non-zero on error.
ZEROPERL_API("zeroperl_init")
int zeroperl_init(void) {
  if (zero_perl) {
    return 0;
  }

  zeroperl_context ctx = {.op_type = ZEROPERL_OP_INIT,
                          .result = 0,
                          .data.init = {.argc = 0, .argv = NULL}};
  return asyncjmp_rt_start(zeroperl_init_callback, 0, (char **)&ctx);
}

//! Initialize the Perl interpreter with command-line arguments
//!
//! Alternative to zeroperl_init() for when you want to run a complete Perl
//! program from a file or with command-line arguments.
//!
//! Returns 0 on success, non-zero on error.
ZEROPERL_API("zeroperl_init_with_args")
int zeroperl_init_with_args(int argc, char **argv) {
  if (zero_perl) {
    return 0;
  }

  if (argc <= 0 || !argv) {
    return zeroperl_init();
  }

  zeroperl_context ctx = {.op_type = ZEROPERL_OP_INIT,
                          .result = 0,
                          .data.init = {.argc = argc, .argv = argv}};
  return asyncjmp_rt_start(zeroperl_init_callback, 0, (char **)&ctx);
}

//! Evaluate a string of Perl code
//!
//! The interpreter must be initialized first. The code is evaluated with
//! the specified context (void, scalar, or list). Optional arguments can
//! be provided which will be available in @ARGV.
//!
//! Returns 0 on success, non-zero on error.
ZEROPERL_API("zeroperl_eval")
int zeroperl_eval(const char *code, zeroperl_context_type context, int argc,
                  char **argv) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return -1;
  }

  if (!code) {
    return -1;
  }

  zeroperl_context ctx = {
      .op_type = ZEROPERL_OP_EVAL,
      .result = 0,
      .data.eval = {
          .code = code, .argc = argc, .argv = argv, .context = context}};
  return asyncjmp_rt_start(zeroperl_eval_callback, 0, (char **)&ctx);
}

//! Run a Perl program file
//!
//! Loads and executes a Perl script file. Arguments can be provided which
//! will be available in @ARGV.
//!
//! Returns 0 on success, non-zero on error.
ZEROPERL_API("zeroperl_run_file")
int zeroperl_run_file(const char *filepath, int argc, char **argv) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return 1;
  }

  if (!filepath) {
    return 1;
  }

  zeroperl_context ctx = {
      .op_type = ZEROPERL_OP_RUN_FILE,
      .result = 0,
      .data.run_file = {.filepath = filepath, .argc = argc, .argv = argv}};
  return asyncjmp_rt_start(zeroperl_run_file_callback, 0, (char **)&ctx);
}

//! Free the Perl interpreter
//!
//! Destructs and frees the interpreter but leaves the Perl system initialized.
//! After this, you can call zeroperl_init() again for a fresh interpreter.
ZEROPERL_API("zeroperl_free_interpreter")
void zeroperl_free_interpreter(void) {
  if (zero_perl) {
    perl_destruct(zero_perl);
    perl_free(zero_perl);
    zero_perl = NULL;
    zero_perl_can_evaluate = false;
  }
}

//! Complete system shutdown
//!
//! Frees the interpreter and performs full Perl system cleanup.
//! Should be called only once at program exit.
ZEROPERL_API("zeroperl_shutdown")
void zeroperl_shutdown(void) {
  zeroperl_free_interpreter();

  if (zero_perl_system_initialized) {
    PERL_SYS_TERM();
    zero_perl_system_initialized = false;
  }
}

//! Clear the error state ($@)
//!
//! Clears both the internal error buffer and the Perl $@ variable.
ZEROPERL_API("zeroperl_clear_error")
void zeroperl_clear_error(void) {
  zero_perl_error_buf[0] = '\0';
  zeroperl_clear_error_internal();
}

//! Reset the interpreter to a clean state
//!
//! Destructs and reconstructs the interpreter, clearing all Perl state.
//! After reset, the interpreter is ready for eval() calls.
//!
//! Returns 0 on success, non-zero on error.
ZEROPERL_API("zeroperl_reset")
int zeroperl_reset(void) {
  if (!zero_perl) {
    const char *err = "Interpreter not initialized";
    strncpy(zero_perl_error_buf, err, sizeof(zero_perl_error_buf) - 1);
    zero_perl_error_buf[sizeof(zero_perl_error_buf) - 1] = '\0';
    return -1;
  }

  zeroperl_clear_error();

  zeroperl_context ctx = {.op_type = ZEROPERL_OP_RESET,
                          .result = 0,
                          .data.init = {.argc = 0, .argv = NULL}};
  return asyncjmp_rt_start(zeroperl_reset_callback, 0, (char **)&ctx);
}

//! Get the last error message from Perl ($@)
//!
//! Returns an empty string if no error. The returned string is owned by
//! zeroperl and valid until the next error occurs.
ZEROPERL_API("zeroperl_last_error")
const char *zeroperl_last_error(void) { return zero_perl_error_buf; }

//! Check if the interpreter is currently initialized
ZEROPERL_API("zeroperl_is_initialized")
bool zeroperl_is_initialized(void) { return zero_perl != NULL; }

//! Check if the interpreter is ready to evaluate code
ZEROPERL_API("zeroperl_can_evaluate")
bool zeroperl_can_evaluate(void) { return zero_perl_can_evaluate; }

//! Flush STDOUT and STDERR buffers
//!
//! Forces any buffered output to be written immediately.
//!
//! Returns 0 on success, -1 if interpreter not initialized.
ZEROPERL_API("zeroperl_flush")
int zeroperl_flush(void) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return -1;
  }

  dTHX;

  PerlIO *pout = PerlIO_stdout();
  if (pout) {
    if (PerlIO_flush(pout) != 0) {
      return -1;
    }
  }

  PerlIO *perr = PerlIO_stderr();
  if (perr) {
    if (PerlIO_flush(perr) != 0) {
      return -1;
    }
  }

  return 0;
}

//! Create a new integer value
ZEROPERL_API("zeroperl_new_int")
zeroperl_value *zeroperl_new_int(int32_t i) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = newSViv(i);
  return val;
}

//! Create a new unsigned integer value
ZEROPERL_API("zeroperl_new_uint")
zeroperl_value *zeroperl_new_uint(uint32_t u) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = newSVuv(u);
  return val;
}

//! Create a new double value
ZEROPERL_API("zeroperl_new_double")
zeroperl_value *zeroperl_new_double(double d) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = newSVnv(d);
  return val;
}

//! Create a new string value (UTF-8)

ZEROPERL_API("zeroperl_new_string")
zeroperl_value *zeroperl_new_string(const char *str, size_t len) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  if (len == 0) {
    val->sv = newSVpvn("", 0);
    SvUTF8_on(val->sv);
    return val;
  }

  if (!str) {
    free(val);
    return NULL;
  }

  val->sv = newSVpvn(str, len);
  SvUTF8_on(val->sv);
  return val;
}

//! Create a new boolean value
ZEROPERL_API("zeroperl_new_bool")
zeroperl_value *zeroperl_new_bool(bool b) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = b ? &PL_sv_yes : &PL_sv_no;
  SvREFCNT_inc(val->sv);
  return val;
}

//! Create a new undef value
ZEROPERL_API("zeroperl_new_undef")
zeroperl_value *zeroperl_new_undef(void) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = newSV(0);
  return val;
}

//! Convert a value to an integer
//!
//! Returns true on success, false if conversion failed.
ZEROPERL_API("zeroperl_to_int")
bool zeroperl_to_int(zeroperl_value *val, int32_t *out) {
  if (!val || !val->sv || !out) {
    return false;
  }

  dTHX;
  *out = (int32_t)SvIV(val->sv);
  return true;
}

//! Convert a value to a double
//!
//! Returns true on success, false if conversion failed.
ZEROPERL_API("zeroperl_to_double")
bool zeroperl_to_double(zeroperl_value *val, double *out) {
  if (!val || !val->sv || !out) {
    return false;
  }

  dTHX;
  *out = SvNV(val->sv);
  return true;
}

//! Convert a value to a UTF-8 string
//!
//! The returned string is owned by the value and should not be freed.
//! If len is not NULL, it will be set to the string length in bytes.
ZEROPERL_API("zeroperl_to_string")
const char *zeroperl_to_string(zeroperl_value *val, size_t *len) {
  if (!val || !val->sv) {
    return NULL;
  }

  dTHX;
  STRLEN perl_len;
  const char *str = SvPVutf8(val->sv, perl_len);

  if (len) {
    *len = perl_len;
  }

  return str;
}

//! Convert a value to a boolean
ZEROPERL_API("zeroperl_to_bool")
bool zeroperl_to_bool(zeroperl_value *val) {
  if (!val || !val->sv) {
    return false;
  }

  dTHX;
  return SvTRUE(val->sv);
}

//! Check if a value is undef
ZEROPERL_API("zeroperl_is_undef")
bool zeroperl_is_undef(zeroperl_value *val) {
  if (!val || !val->sv) {
    return true;
  }

  dTHX;
  return !SvOK(val->sv);
}

//! Get the type of a value
ZEROPERL_API("zeroperl_get_type")
zeroperl_type zeroperl_get_type(zeroperl_value *val) {
  if (!val || !val->sv) {
    return ZEROPERL_TYPE_UNDEF;
  }

  dTHX;
  SV *sv = val->sv;

  if (!SvOK(sv)) {
    return ZEROPERL_TYPE_UNDEF;
  }

  if (sv == &PL_sv_yes) {
    return ZEROPERL_TYPE_TRUE;
  }
  if (sv == &PL_sv_no) {
    return ZEROPERL_TYPE_FALSE;
  }

  if (SvROK(sv)) {
    SV *rv = SvRV(sv);
    svtype type = SvTYPE(rv);

    if (type == SVt_PVAV) {
      return ZEROPERL_TYPE_ARRAY;
    } else if (type == SVt_PVHV) {
      return ZEROPERL_TYPE_HASH;
    } else if (type == SVt_PVCV) {
      return ZEROPERL_TYPE_CODE;
    }

    return ZEROPERL_TYPE_REF;
  }

  if (SvIOK(sv)) {
    return ZEROPERL_TYPE_INT;
  }

  if (SvNOK(sv)) {
    return ZEROPERL_TYPE_DOUBLE;
  }

  if (SvPOK(sv)) {
    return ZEROPERL_TYPE_STRING;
  }

  return ZEROPERL_TYPE_UNDEF;
}

//! Increment the reference count of a value
ZEROPERL_API("zeroperl_incref")
void zeroperl_incref(zeroperl_value *val) {
  if (!val || !val->sv) {
    return;
  }

  dTHX;
  SvREFCNT_inc(val->sv);
}

//! Decrement the reference count of a value
ZEROPERL_API("zeroperl_decref")
void zeroperl_decref(zeroperl_value *val) {
  if (!val || !val->sv) {
    return;
  }

  dTHX;
  SvREFCNT_dec(val->sv);
}

//! Free a value
//!
//! Decrements the reference count and frees the handle structure.
ZEROPERL_API("zeroperl_value_free")
void zeroperl_value_free(zeroperl_value *val) {
  if (!val) {
    return;
  }

  if (val->sv) {
    dTHX;
    SvREFCNT_dec(val->sv);
  }

  free(val);
}

//! Create a new empty array
ZEROPERL_API("zeroperl_new_array")
zeroperl_array *zeroperl_new_array(void) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_array *arr = (zeroperl_array *)malloc(sizeof(zeroperl_array));
  if (!arr) {
    return NULL;
  }

  arr->av = newAV();
  return arr;
}

//! Push a value onto the end of an array
ZEROPERL_API("zeroperl_array_push")
void zeroperl_array_push(zeroperl_array *arr, zeroperl_value *val) {
  if (!arr || !arr->av || !val || !val->sv) {
    return;
  }

  dTHX;
  av_push(arr->av, SvREFCNT_inc(val->sv));
}

//! Pop a value from the end of an array
//!
//! Returns NULL if the array is empty. The caller must free the returned value.
ZEROPERL_API("zeroperl_array_pop")
zeroperl_value *zeroperl_array_pop(zeroperl_array *arr) {
  if (!arr || !arr->av) {
    return NULL;
  }

  dTHX;
  SV *sv = av_pop(arr->av);

  if (!sv || sv == &PL_sv_undef) {
    return NULL;
  }

  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    SvREFCNT_dec(sv);
    return NULL;
  }

  val->sv = sv;
  return val;
}

//! Get a value from an array at the specified index
//!
//! Returns NULL if the index is out of bounds. The returned value is a new
//! handle and must be freed.
ZEROPERL_API("zeroperl_array_get")
zeroperl_value *zeroperl_array_get(zeroperl_array *arr, size_t index) {
  if (!arr || !arr->av) {
    return NULL;
  }

  dTHX;
  SSize_t top = av_top_index(arr->av);

  if (index > (size_t)top) {
    return NULL;
  }

  SV **svp = av_fetch(arr->av, (SSize_t)index, 0);
  if (!svp || !*svp) {
    return NULL;
  }

  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = SvREFCNT_inc(*svp);
  return val;
}

//! Set a value in an array at the specified index
//!
//! Returns true on success, false on failure.
ZEROPERL_API("zeroperl_array_set")
bool zeroperl_array_set(zeroperl_array *arr, size_t index,
                        zeroperl_value *val) {
  if (!arr || !arr->av || !val || !val->sv) {
    return false;
  }

  dTHX;
  SV **svp = av_store(arr->av, (SSize_t)index, SvREFCNT_inc(val->sv));
  return svp != NULL;
}

//! Get the length of an array
ZEROPERL_API("zeroperl_array_length")
size_t zeroperl_array_length(zeroperl_array *arr) {
  if (!arr || !arr->av) {
    return 0;
  }

  dTHX;
  SSize_t top = av_top_index(arr->av);
  return (top < 0) ? 0 : (size_t)(top + 1);
}

//! Clear all elements from an array
ZEROPERL_API("zeroperl_array_clear")
void zeroperl_array_clear(zeroperl_array *arr) {
  if (!arr || !arr->av) {
    return;
  }

  dTHX;
  av_clear(arr->av);
}

//! Convert an array to a value
//!
//! Creates a reference to the array. The caller must free the returned value.
ZEROPERL_API("zeroperl_array_to_value")
zeroperl_value *zeroperl_array_to_value(zeroperl_array *arr) {
  if (!arr || !arr->av) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = newRV_inc((SV *)arr->av);
  return val;
}

//! Convert a value to an array
//!
//! Returns NULL if the value is not an array reference. The caller must free
//! the returned array.
ZEROPERL_API("zeroperl_value_to_array")
zeroperl_array *zeroperl_value_to_array(zeroperl_value *val) {
  if (!val || !val->sv) {
    return NULL;
  }

  dTHX;

  if (!SvROK(val->sv)) {
    return NULL;
  }

  SV *rv = SvRV(val->sv);
  if (SvTYPE(rv) != SVt_PVAV) {
    return NULL;
  }

  zeroperl_array *arr = (zeroperl_array *)malloc(sizeof(zeroperl_array));
  if (!arr) {
    return NULL;
  }

  arr->av = (AV *)SvREFCNT_inc(rv);
  return arr;
}

//! Free an array
ZEROPERL_API("zeroperl_array_free")
void zeroperl_array_free(zeroperl_array *arr) {
  if (!arr) {
    return;
  }

  if (arr->av) {
    dTHX;
    SvREFCNT_dec((SV *)arr->av);
  }

  free(arr);
}

//! Create a new empty hash
ZEROPERL_API("zeroperl_new_hash")
zeroperl_hash *zeroperl_new_hash(void) {
  if (!zero_perl || !zero_perl_can_evaluate) {
    return NULL;
  }

  dTHX;
  zeroperl_hash *hash = (zeroperl_hash *)malloc(sizeof(zeroperl_hash));
  if (!hash) {
    return NULL;
  }

  hash->hv = newHV();
  return hash;
}

//! Set a value in a hash
//!
//! Returns true on success, false on failure.
ZEROPERL_API("zeroperl_hash_set")
bool zeroperl_hash_set(zeroperl_hash *hash, const char *key,
                       zeroperl_value *val) {
  if (!hash || !hash->hv || !key || !val || !val->sv) {
    return false;
  }

  dTHX;
  SV **svp = hv_store(hash->hv, key, strlen(key), SvREFCNT_inc(val->sv), 0);
  return svp != NULL;
}

//! Get a value from a hash
//!
//! Returns NULL if the key doesn't exist. The caller must free the returned
//! value.
ZEROPERL_API("zeroperl_hash_get")
zeroperl_value *zeroperl_hash_get(zeroperl_hash *hash, const char *key) {
  if (!hash || !hash->hv || !key) {
    return NULL;
  }

  dTHX;
  SV **svp = hv_fetch(hash->hv, key, strlen(key), 0);

  if (!svp || !*svp) {
    return NULL;
  }

  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = SvREFCNT_inc(*svp);
  return val;
}

//! Check if a key exists in a hash
ZEROPERL_API("zeroperl_hash_exists")
bool zeroperl_hash_exists(zeroperl_hash *hash, const char *key) {
  if (!hash || !hash->hv || !key) {
    return false;
  }

  dTHX;
  return hv_exists(hash->hv, key, strlen(key));
}

//! Delete a key from a hash
//!
//! Returns true if the key was deleted, false if it didn't exist.
ZEROPERL_API("zeroperl_hash_delete")
bool zeroperl_hash_delete(zeroperl_hash *hash, const char *key) {
  if (!hash || !hash->hv || !key) {
    return false;
  }

  dTHX;
  SV *sv = hv_delete(hash->hv, key, strlen(key), 0);

  if (sv) {
    SvREFCNT_dec(sv);
    return true;
  }

  return false;
}

//! Clear all entries from a hash
ZEROPERL_API("zeroperl_hash_clear")
void zeroperl_hash_clear(zeroperl_hash *hash) {
  if (!hash || !hash->hv) {
    return;
  }

  dTHX;
  hv_clear(hash->hv);
}

//! Create a new hash iterator
//!
//! The caller must free the iterator with zeroperl_hash_iter_free().
ZEROPERL_API("zeroperl_hash_iter_new")
zeroperl_hash_iter *zeroperl_hash_iter_new(zeroperl_hash *hash) {
  if (!hash || !hash->hv) {
    return NULL;
  }

  dTHX;
  zeroperl_hash_iter *iter =
      (zeroperl_hash_iter *)malloc(sizeof(zeroperl_hash_iter));
  if (!iter) {
    return NULL;
  }

  iter->hv = hash->hv;
  hv_iterinit(iter->hv);
  iter->entry = NULL;

  return iter;
}

//! Get the next key-value pair from a hash iterator
//!
//! Returns true if a pair was retrieved, false if the end was reached.
//! The key string is owned by Perl and should not be freed. The value must
//! be freed by the caller.
ZEROPERL_API("zeroperl_hash_iter_next")
bool zeroperl_hash_iter_next(zeroperl_hash_iter *iter, const char **key,
                             zeroperl_value **val) {
  if (!iter || !iter->hv) {
    return false;
  }

  dTHX;
  iter->entry = hv_iternext(iter->hv);

  if (!iter->entry) {
    return false;
  }

  if (key) {
    I32 retlen;
    *key = hv_iterkey(iter->entry, &retlen);
  }

  if (val) {
    SV *sv = hv_iterval(iter->hv, iter->entry);

    zeroperl_value *value = (zeroperl_value *)malloc(sizeof(zeroperl_value));
    if (!value) {
      return false;
    }

    value->sv = SvREFCNT_inc(sv);
    *val = value;
  }

  return true;
}

//! Free a hash iterator
ZEROPERL_API("zeroperl_hash_iter_free")
void zeroperl_hash_iter_free(zeroperl_hash_iter *iter) {
  if (!iter) {
    return;
  }

  free(iter);
}

//! Convert a hash to a value
//!
//! Creates a reference to the hash. The caller must free the returned value.
ZEROPERL_API("zeroperl_hash_to_value")
zeroperl_value *zeroperl_hash_to_value(zeroperl_hash *hash) {
  if (!hash || !hash->hv) {
    return NULL;
  }

  dTHX;
  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = newRV_inc((SV *)hash->hv);
  return val;
}

//! Convert a value to a hash
//!
//! Returns NULL if the value is not a hash reference. The caller must free
//! the returned hash.
ZEROPERL_API("zeroperl_value_to_hash")
zeroperl_hash *zeroperl_value_to_hash(zeroperl_value *val) {
  if (!val || !val->sv) {
    return NULL;
  }

  dTHX;

  if (!SvROK(val->sv)) {
    return NULL;
  }

  SV *rv = SvRV(val->sv);
  if (SvTYPE(rv) != SVt_PVHV) {
    return NULL;
  }

  zeroperl_hash *hash = (zeroperl_hash *)malloc(sizeof(zeroperl_hash));
  if (!hash) {
    return NULL;
  }

  hash->hv = (HV *)SvREFCNT_inc(rv);
  return hash;
}

//! Free a hash
ZEROPERL_API("zeroperl_hash_free")
void zeroperl_hash_free(zeroperl_hash *hash) {
  if (!hash) {
    return;
  }

  if (hash->hv) {
    dTHX;
    SvREFCNT_dec((SV *)hash->hv);
  }

  free(hash);
}

//! Create a new reference to a value
//!
//! The caller must free the returned value.
ZEROPERL_API("zeroperl_new_ref")
zeroperl_value *zeroperl_new_ref(zeroperl_value *val) {
  if (!val || !val->sv) {
    return NULL;
  }

  dTHX;
  zeroperl_value *ref = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!ref) {
    return NULL;
  }

  ref->sv = newRV_inc(val->sv);
  return ref;
}

//! Dereference a value
//!
//! Returns NULL if the value is not a reference. The caller must free the
//! returned value.
ZEROPERL_API("zeroperl_deref")
zeroperl_value *zeroperl_deref(zeroperl_value *ref) {
  if (!ref || !ref->sv) {
    return NULL;
  }

  dTHX;

  if (!SvROK(ref->sv)) {
    return NULL;
  }

  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = SvREFCNT_inc(SvRV(ref->sv));
  return val;
}

//! Check if a value is a reference
ZEROPERL_API("zeroperl_is_ref")
bool zeroperl_is_ref(zeroperl_value *val) {
  if (!val || !val->sv) {
    return false;
  }

  dTHX;
  return SvROK(val->sv);
}

//! Get a global scalar variable
//!
//! Returns NULL if the variable doesn't exist. The caller must free the
//! returned value.
ZEROPERL_API("zeroperl_get_var")
zeroperl_value *zeroperl_get_var(const char *name) {
  if (!zero_perl || !zero_perl_can_evaluate || !name) {
    return NULL;
  }

  dTHX;
  SV *sv = get_sv(name, 0);

  if (!sv) {
    return NULL;
  }

  zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
  if (!val) {
    return NULL;
  }

  val->sv = SvREFCNT_inc(sv);
  return val;
}

//! Get a global array variable
//!
//! Returns NULL if the variable doesn't exist. The caller must free the
//! returned array.
ZEROPERL_API("zeroperl_get_array_var")
zeroperl_array *zeroperl_get_array_var(const char *name) {
  if (!zero_perl || !zero_perl_can_evaluate || !name) {
    return NULL;
  }

  dTHX;
  AV *av = get_av(name, 0);

  if (!av) {
    return NULL;
  }

  zeroperl_array *arr = (zeroperl_array *)malloc(sizeof(zeroperl_array));
  if (!arr) {
    return NULL;
  }

  arr->av = (AV *)SvREFCNT_inc((SV *)av);
  return arr;
}

//! Get a global hash variable
//!
//! Returns NULL if the variable doesn't exist. The caller must free the
//! returned hash.
ZEROPERL_API("zeroperl_get_hash_var")
zeroperl_hash *zeroperl_get_hash_var(const char *name) {
  if (!zero_perl || !zero_perl_can_evaluate || !name) {
    return NULL;
  }

  dTHX;
  HV *hv = get_hv(name, 0);

  if (!hv) {
    return NULL;
  }

  zeroperl_hash *hash = (zeroperl_hash *)malloc(sizeof(zeroperl_hash));
  if (!hash) {
    return NULL;
  }

  hash->hv = (HV *)SvREFCNT_inc((SV *)hv);
  return hash;
}

//! Set a global scalar variable
//!
//! Returns true on success, false on failure.
ZEROPERL_API("zeroperl_set_var")
bool zeroperl_set_var(const char *name, zeroperl_value *val) {
  if (!zero_perl || !zero_perl_can_evaluate || !name || !val || !val->sv) {
    return false;
  }

  dTHX;
  SV *sv = get_sv(name, GV_ADD);

  if (!sv) {
    return false;
  }

  sv_setsv(sv, val->sv);
  return true;
}

//! Register a host function that can be called from Perl
//!
//! The function will be available as a Perl subroutine with the given name.
//! When called from Perl, it will invoke the host's call_host_function with
//! the provided func_id.
ZEROPERL_API("zeroperl_register_function")
void zeroperl_register_function(int32_t func_id, const char *name) {
  if (!zero_perl || !zero_perl_can_evaluate || !name) {
    return;
  }

  if (host_function_count >= MAX_HOST_FUNCTIONS) {
    return;
  }

  dTHX;

  CV *cv = newXS(name, xs_host_dispatch, __FILE__);
  if (!cv) {
    return;
  }

  CvXSUBANY(cv).any_i32 = func_id;

  host_function_entry *entry = &host_functions[host_function_count++];
  entry->func_id = func_id;
  entry->name = strdup(name);
  entry->package = NULL;
  entry->is_method = false;
}

//! Register a host method that can be called from Perl
//!
//! The method will be available in the specified package. When called from
//! Perl, it will invoke the host's call_host_function with the provided
//! func_id.
ZEROPERL_API("zeroperl_register_method")
void zeroperl_register_method(int32_t func_id, const char *package,
                              const char *method) {
  if (!zero_perl || !zero_perl_can_evaluate || !package || !method) {
    return;
  }

  if (host_function_count >= MAX_HOST_FUNCTIONS) {
    return;
  }

  dTHX;

  char full_name[256];
  snprintf(full_name, sizeof(full_name), "%s::%s", package, method);

  CV *cv = newXS(full_name, xs_host_dispatch, __FILE__);
  if (!cv) {
    return;
  }

  CvXSUBANY(cv).any_i32 = func_id;

  host_function_entry *entry = &host_functions[host_function_count++];
  entry->func_id = func_id;
  entry->name = strdup(method);
  entry->package = strdup(package);
  entry->is_method = true;
}

//! Internal callback for calling Perl subroutines
static int zeroperl_call_callback(int argc, char **argv) {
  (void)argc;
  zeroperl_context *ctx = (zeroperl_context *)argv;

  if (!zero_perl || !zero_perl_can_evaluate) {
    ctx->result = -1;
    return -1;
  }

  zeroperl_clear_error_internal();

  dTHX;
  dSP;

  ENTER;
  SAVETMPS;

  PUSHMARK(SP);

  for (int i = 0; i < ctx->data.call.argc; i++) {
    if (ctx->data.call.argv[i] && ctx->data.call.argv[i]->sv) {
      XPUSHs(sv_2mortal(SvREFCNT_inc(ctx->data.call.argv[i]->sv)));
    }
  }

  PUTBACK;

  I32 gimme;
  switch (ctx->data.call.context) {
  case ZEROPERL_VOID:
    gimme = G_VOID;
    break;
  case ZEROPERL_LIST:
    gimme = G_ARRAY;
    break;
  case ZEROPERL_SCALAR:
  default:
    gimme = G_SCALAR;
    break;
  }

  int count = call_pv(ctx->data.call.name, gimme | G_EVAL);

  SPAGAIN;

  // Check if an error occurred
  if (SvTRUE(ERRSV)) {
    zeroperl_capture_error();
    ctx->result = -1;
    FREETMPS;
    LEAVE;
    return -1;
  }

  zeroperl_result *result = (zeroperl_result *)malloc(sizeof(zeroperl_result));
  if (!result) {
    ctx->result = -1;
    FREETMPS;
    LEAVE;
    return -1;
  }

  result->count = count;

  if (count > 0) {
    result->values =
        (zeroperl_value **)malloc(sizeof(zeroperl_value *) * count);
    if (!result->values) {
      free(result);
      ctx->result = -1;
      FREETMPS;
      LEAVE;
      return -1;
    }

    for (int i = count - 1; i >= 0; i--) {
      zeroperl_value *val = (zeroperl_value *)malloc(sizeof(zeroperl_value));
      if (val) {
        val->sv = SvREFCNT_inc(POPs);
        result->values[i] = val;
      } else {
        result->values[i] = NULL;
      }
    }
  } else {
    result->values = NULL;
  }

  PUTBACK;
  FREETMPS;
  LEAVE;

  // Store result pointer in context (caller will retrieve it)
  *((zeroperl_result **)&ctx->result) = result;
  return 0;
}

//! Call a Perl subroutine
//!
//! Returns a result structure containing the return values. The caller must
//! free the result with zeroperl_result_free().
ZEROPERL_API("zeroperl_call")
zeroperl_result *zeroperl_call(const char *name, zeroperl_context_type context,
                               int argc, zeroperl_value **argv) {
  if (!zero_perl || !zero_perl_can_evaluate || !name) {
    return NULL;
  }

  zeroperl_context ctx = {
      .op_type = ZEROPERL_OP_CALL,
      .result = 0,
      .data.call = {
          .name = name, .argc = argc, .argv = argv, .context = context}};

  int status = asyncjmp_rt_start(zeroperl_call_callback, 0, (char **)&ctx);

  if (status != 0) {
    return NULL;
  }

  return *((zeroperl_result **)&ctx.result);
}

//! Get a value from a result by index
//!
//! Returns NULL if the index is out of bounds. The returned value is owned
//! by the result and should not be freed directly.
ZEROPERL_API("zeroperl_result_get")
zeroperl_value *zeroperl_result_get(zeroperl_result *result, int index) {
  if (!result || index < 0 || index >= result->count) {
    return NULL;
  }

  return result->values[index];
}

//! Free a result structure
//!
//! Also frees all values contained in the result.
ZEROPERL_API("zeroperl_result_free")
void zeroperl_result_free(zeroperl_result *result) {
  if (!result) {
    return;
  }

  if (result->values) {
    for (int i = 0; i < result->count; i++) {
      if (result->values[i]) {
        zeroperl_value_free(result->values[i]);
      }
    }
    free(result->values);
  }

  free(result);
}

#ifdef ZEROPERL_USE_GENERATED_XS_INIT
#include "xs_init.inc"
#else
EXTERN_C void boot_DynaLoader(pTHX_ CV *cv);
EXTERN_C void boot_File__Glob(pTHX_ CV *cv);
EXTERN_C void boot_Sys__Hostname(pTHX_ CV *cv);
EXTERN_C void boot_PerlIO__via(pTHX_ CV *cv);
EXTERN_C void boot_PerlIO__mmap(pTHX_ CV *cv);
EXTERN_C void boot_PerlIO__encoding(pTHX_ CV *cv);
EXTERN_C void boot_attributes(pTHX_ CV *cv);
EXTERN_C void boot_Unicode__Normalize(pTHX_ CV *cv);
EXTERN_C void boot_Unicode__Collate(pTHX_ CV *cv);
EXTERN_C void boot_re(pTHX_ CV *cv);
EXTERN_C void boot_Digest__MD5(pTHX_ CV *cv);
EXTERN_C void boot_Digest__SHA(pTHX_ CV *cv);
EXTERN_C void boot_Math__BigInt__FastCalc(pTHX_ CV *cv);
EXTERN_C void boot_Data__Dumper(pTHX_ CV *cv);
EXTERN_C void boot_I18N__Langinfo(pTHX_ CV *cv);
EXTERN_C void boot_Time__Piece(pTHX_ CV *cv);
EXTERN_C void boot_IO(pTHX_ CV *cv);
EXTERN_C void boot_Hash__Util__FieldHash(pTHX_ CV *cv);
EXTERN_C void boot_Hash__Util(pTHX_ CV *cv);
EXTERN_C void boot_Filter__Util__Call(pTHX_ CV *cv);
EXTERN_C void boot_Encode__Unicode(pTHX_ CV *cv);
EXTERN_C void boot_Encode(pTHX_ CV *cv);
EXTERN_C void boot_Encode__JP(pTHX_ CV *cv);
EXTERN_C void boot_Encode__KR(pTHX_ CV *cv);
EXTERN_C void boot_Encode__EBCDIC(pTHX_ CV *cv);
EXTERN_C void boot_Encode__CN(pTHX_ CV *cv);
EXTERN_C void boot_Encode__Symbol(pTHX_ CV *cv);
EXTERN_C void boot_Encode__Byte(pTHX_ CV *cv);
EXTERN_C void boot_Encode__TW(pTHX_ CV *cv);
EXTERN_C void boot_Compress__Raw__Zlib(pTHX_ CV *cv);
EXTERN_C void boot_Compress__Raw__Bzip2(pTHX_ CV *cv);
EXTERN_C void boot_MIME__Base64(pTHX_ CV *cv);
EXTERN_C void boot_Cwd(pTHX_ CV *cv);
EXTERN_C void boot_List__Util(pTHX_ CV *cv);
EXTERN_C void boot_Fcntl(pTHX_ CV *cv);
EXTERN_C void boot_Opcode(pTHX_ CV *cv);
EXTERN_C void boot_Time__HiRes(pTHX_ CV* cv);

static void xs_init(pTHX) {
  static const char file[] = __FILE__;
  dXSUB_SYS;
  PERL_UNUSED_CONTEXT;

  newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
  newXS("File::Glob::bootstrap", boot_File__Glob, file);
  newXS("Sys::Hostname::bootstrap", boot_Sys__Hostname, file);
  newXS("PerlIO::via::bootstrap", boot_PerlIO__via, file);
  newXS("PerlIO::mmap::bootstrap", boot_PerlIO__mmap, file);
  newXS("PerlIO::encoding::bootstrap", boot_PerlIO__encoding, file);
  newXS("attributes::bootstrap", boot_attributes, file);
  newXS("Unicode::Normalize::bootstrap", boot_Unicode__Normalize, file);
  newXS("Unicode::Collate::bootstrap", boot_Unicode__Collate, file);
  newXS("re::bootstrap", boot_re, file);
  newXS("Digest::MD5::bootstrap", boot_Digest__MD5, file);
  newXS("Digest::SHA::bootstrap", boot_Digest__SHA, file);
  newXS("Math::BigInt::FastCalc::bootstrap", boot_Math__BigInt__FastCalc, file);
  newXS("Data::Dumper::bootstrap", boot_Data__Dumper, file);
  newXS("I18N::Langinfo::bootstrap", boot_I18N__Langinfo, file);
  newXS("Time::Piece::bootstrap", boot_Time__Piece, file);
  newXS("IO::bootstrap", boot_IO, file);
  newXS("Hash::Util::FieldHash::bootstrap", boot_Hash__Util__FieldHash, file);
  newXS("Hash::Util::bootstrap", boot_Hash__Util, file);
  newXS("Filter::Util::Call::bootstrap", boot_Filter__Util__Call, file);
  newXS("Encode::Unicode::bootstrap", boot_Encode__Unicode, file);
  newXS("Encode::bootstrap", boot_Encode, file);
  newXS("Encode::JP::bootstrap", boot_Encode__JP, file);
  newXS("Encode::KR::bootstrap", boot_Encode__KR, file);
  newXS("Encode::EBCDIC::bootstrap", boot_Encode__EBCDIC, file);
  newXS("Encode::CN::bootstrap", boot_Encode__CN, file);
  newXS("Encode::Symbol::bootstrap", boot_Encode__Symbol, file);
  newXS("Encode::Byte::bootstrap", boot_Encode__Byte, file);
  newXS("Encode::TW::bootstrap", boot_Encode__TW, file);
  newXS("Compress::Raw::Zlib::bootstrap", boot_Compress__Raw__Zlib, file);
  newXS("Compress::Raw::Bzip2::bootstrap", boot_Compress__Raw__Bzip2, file);
  newXS("MIME::Base64::bootstrap", boot_MIME__Base64, file);
  newXS("Cwd::bootstrap", boot_Cwd, file);
  newXS("List::Util::bootstrap", boot_List__Util, file);
  newXS("Fcntl::bootstrap", boot_Fcntl, file);
  newXS("Opcode::bootstrap", boot_Opcode, file);
  newXS("Time::HiRes::bootstrap", boot_Time__HiRes, file);
}
#endif
