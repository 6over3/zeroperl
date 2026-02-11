#ifndef ZEROPERL_H
#define ZEROPERL_H

#include "EXTERN.h"
#include "XSUB.h"
#include "perl.h"
#include <stdint.h>


// Defined for SFS (Simple File System) prefix
#ifndef SFS_BUILTIN_PREFIX
#define SFS_BUILTIN_PREFIX "builtin:"
#endif

// Opaque handle to a Perl scalar value
typedef struct zeroperl_value_s {
  SV *sv;
} zeroperl_value;

// Opaque handle to a Perl array
typedef struct zeroperl_array_s {
  AV *av;
} zeroperl_array;

// Opaque handle to a Perl hash
typedef struct zeroperl_hash_s {
  HV *hv;
} zeroperl_hash;

// Opaque handle to a Perl code reference
typedef struct zeroperl_code_s {
  CV *cv;
} zeroperl_code;

// Result structure for operations that return multiple values
typedef struct zeroperl_result_s {
  int count;
  zeroperl_value **values;
} zeroperl_result;

// Iterator for hash traversal
typedef struct zeroperl_hash_iter_s {
  HV *hv;
  HE *entry;
} zeroperl_hash_iter;

// Context type for calling Perl code
typedef enum {
  ZEROPERL_VOID,
  ZEROPERL_SCALAR,
  ZEROPERL_LIST
} zeroperl_context_type;

// Value type enumeration
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

// Operation type for unified context
typedef enum {
  ZEROPERL_OP_INIT,
  ZEROPERL_OP_EVAL,
  ZEROPERL_OP_RUN_FILE,
  ZEROPERL_OP_RESET,
  ZEROPERL_OP_CALL
} zeroperl_op_type;

// Unified context structure for all Perl operations
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

// Cleanup helper
void zeroperl_value_free(zeroperl_value *val);

// Host call function
zeroperl_value *host_call_function(int32_t func_id, int32_t argc,
                                   zeroperl_value **argv);

// Error handling functions
void zeroperl_set_host_error(const char *error);
const char *zeroperl_get_host_error(void);
void zeroperl_clear_host_error(void);

#endif // ZEROPERL_H
