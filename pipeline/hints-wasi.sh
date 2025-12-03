# WASI hints for Perl cross-compilation
# Based on actual WASM32 type sizes from wasi-sdk

# Architecture
osname='wasi'
archname='wasm32-wasi'
archname64='wasi'
osvers='__WASI_SDK_VERSION__'
myuname='zeroperl'
myhostname='6over3.com'
mydomain='6over3.com'
perladmin='lena'

# Build tools (placeholders replaced by build script)
cc='wasic'
ld='wasic'
ar='__WASI_SDK_PATH__/bin/llvm-ar'
ranlib='__WASI_SDK_PATH__/bin/llvm-ranlib'
optimize='-O2'

# Cross-compilation
hostperl='__NATIVE_DIR__/miniperl'
hostgenerate='__NATIVE_DIR__/generate_uudmap'
sysroot='__WASI_SDK_PATH__/share/wasi-sysroot'

# Installation
prefix='/zeroperl'
inc_version_list='none'
man1dir='none'
man3dir='none'
lns='/bin/ln -sf'

# Disable dynamic loading
dlsrc='none'
loclibpth=''
glibpth=''

# Preprocessor workarounds
d_setlocale='undef'
d_perl_lc_all_uses_name_value_pairs='undef'
d_perl_lc_all_separator='define'
perl_lc_all_separator=';'
d_perl_lc_all_category_positions_init='define'
perl_lc_all_category_positions_init='{ 0, 1, 2, 3, 4, 5 }'

# Memory/threading
usemymalloc='n'
usemultiplicity='undef'
usenm='undef'
usemallocwrap='define'
usethreads='undef'

# Unavailable system features
d_procselfexe='undef'
d_dlopen='undef'
d_wait='undef'
d_waitpid='undef'
d_wait3='undef'
d_wait4='undef'
i_syswait='undef'
d_vfork='undef'
d_pseudofork='undef'
d_killpg='undef'
d_pause='undef'
d_syscall='undef'

# User/group functions unavailable
i_grp='define'
i_pwd='define'
d_getpwnam='undef'
d_getpwent='undef'
d_getpwuid='undef'
d_getspnam='undef'
d_getpwnam_r='undef'
d_getpwent_r='undef'
d_getpwuid_r='undef'
d_getprpwnam='undef'
d_setpwent='undef'
d_setpwent_r='undef'
d_getgrnam='undef'
d_getgrgid='undef'
d_getgrent='undef'
d_getgrnam_r='undef'
d_getgrgid_r='undef'
d_getgrent_r='undef'
d_setgrent='undef'
d_setgrent_r='undef'
d_endgrent='undef'
d_endgrent_r='undef'
d_getuid='undef'
d_geteuid='undef'
d_getgid='undef'
d_getegid='undef'
d_setrgid='undef'
d_setruid='undef'

# IPC unavailable
d_msgctl='undef'
d_msgget='undef'
d_msgrcv='undef'
d_msgsnd='undef'
d_semget='undef'
d_semop='undef'
d_shmat='undef'
d_shmctl='undef'
d_shmdt='undef'
d_shmget='undef'

# pthreads unavailable
i_pthread='undef'
d_pthread_atfork='undef'
d_pthread_attr_setscope='undef'
d_pthread_yield='undef'

# Misc unavailable
d_setproctitle='undef'
d_malloc_size='undef'
d_malloc_good_size='undef'
d_clearenv='undef'
d_cuserid='undef'
d_eaccess='undef'

# File operations
useperlio='define'
d_stat='define'
d_fstat='define'
d_lstat='define'
d_lseek='define'
d_fseeko='define'
d_ftello='define'
d_statblks='undef'
d_fdclose='undef'
d_dirnamlen='undef'
d_llseek='undef'

# WASM32 C type sizes
charsize='1'
shortsize='2'
intsize='4'
longsize='4'
longlongsize='8'
doublesize='8'
longdblsize='16'
ptrsize='4'
alignbytes='4'
sizesize='4'
ssizesize='4'
sizetype='size_t'
ssizetype='ssize_t'

# 64-bit integer support (using long long since long=4)
use64bitint='define'
use64bitall='undef'
ivtype='long long'
uvtype='unsigned long long'
ivsize='8'
uvsize='8'
d_quad='define'
quadtype='long long'
uquadtype='unsigned long long'
quadkind='3'

# Explicit type definitions
i8type='signed char'
u8type='unsigned char'
i16type='short'
u16type='unsigned short'
i32type='int'
u32type='unsigned int'
i64type='long long'
u64type='unsigned long long'
i8size='1'
u8size='1'
i16size='2'
u16size='2'
i32size='4'
u32size='4'
i64size='8'
u64size='8'

# Floating point
nvtype='double'
nvsize='8'
nv_preserves_uv_bits='53'
d_nv_preserves_uv='undef'
usequadmath='undef'
uselongdouble='undef'

# Large file support (off_t is 8 bytes on WASI)
uselargefiles='define'
lseektype='off_t'
lseeksize='8'
fpostype='fpos_t'
fpossize='16'
d_off64_t='undef'
d_fstat64='undef'
d_stat64='undef'
d_lseek64='undef'
d_fseeko64='undef'
d_ftello64='undef'
d_readdir64_r='undef'

# Disabled extensions
noextensions='Socket POSIX Devel/Peek Sys/Syslog B threads threads/shared IPC/SysV SDBM_File Storable'

# Static extensions to build
static_ext='mro File/DosGlob Time/HiRes File/Glob Sys/Hostname PerlIO/via PerlIO/mmap PerlIO/encoding attributes Unicode/Normalize Unicode/Collate re Digest/MD5 Digest/SHA Math/BigInt/FastCalc Data/Dumper I18N/Langinfo Time/Piece IO Hash/Util/FieldHash Hash/Util Filter/Util/Call Encode/Unicode Encode Encode/JP Encode/KR Encode/EBCDIC Encode/CN Encode/Symbol Encode/Byte Encode/TW Compress/Raw/Zlib Compress/Raw/Bzip2 MIME/Base64 Cwd List/Util Fcntl Opcode'

# Compiler/linker flags
ccflags='-DBIG_TIME -DNO_MATHOMS -Wno-int-conversion -Wno-implicit-function-declaration -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID -D_GNU_SOURCE -D_POSIX_C_SOURCE -Wno-null-pointer-arithmetic -D_WASI_EMULATED_SIGNAL -include __WASI_SDK_PATH__/share/wasi-sysroot/include/wasm32-wasi/fcntl.h -I__STUBS_DIR__'

cppflags='-DBIG_TIME -DNO_MATHOMS -Wno-int-conversion -Wno-implicit-function-declaration -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_GETPID -D_GNU_SOURCE -D_POSIX_C_SOURCE -DSTANDARD_C -DPERL_USE_SAFE_PUTENV -D_WASI_EMULATED_SIGNAL -Wno-null-pointer-arithmetic -fno-strict-aliasing -pipe -fstack-protector-strong -include __WASI_SDK_PATH__/share/wasi-sysroot/include/wasm32-wasi/fcntl.h -I__STUBS_DIR__'

ldflags='-static -lwasi-emulated-signal -lwasi-emulated-getpid -lwasi-emulated-process-clocks -lwasi-emulated-mman'

libs='-lm -lwasi-emulated-signal -lwasi-emulated-getpid -lwasi-emulated-process-clocks -lwasi-emulated-mman'