#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/xattr.h>
#include <unistd.h>

/* NAR cannot retain xattrs. Emulate only Wine's directory reparse records
 * inside the explicit build prefix; all other attributes use libc unchanged. */
#define RECORD ".nix-overlayfs-winereparse"
static int eligible(int fd, const char *name)
{
    struct stat st;
    char proc[64], path[PATH_MAX], root[PATH_MAX];
    const char *prefix = getenv("WINEPREFIX");
    if (strcmp(name, "user.WINEREPARSE") || !prefix ||
        !realpath(prefix, root) || fstat(fd, &st) || !S_ISDIR(st.st_mode)) return 0;
    snprintf(proc, sizeof(proc), "/proc/self/fd/%d", fd);
    ssize_t n = readlink(proc, path, sizeof(path) - 1);
    if (n < 0) return 0;
    path[n] = 0;
    size_t len = strlen(root);
    return !strncmp(path, root, len) && (path[len] == '/' || path[len] == 0);
}

int fsetxattr(int fd, const char *name, const void *value, size_t size, int flags)
{
    static int (*original)(int, const char *, const void *, size_t, int);
    if (!original) original = dlsym(RTLD_NEXT, "fsetxattr");
    if (!eligible(fd, name)) return original(fd, name, value, size, flags);
    struct stat st;
    int exists = fstatat(fd, RECORD, &st, AT_SYMLINK_NOFOLLOW) == 0;
    if ((flags & XATTR_CREATE) && exists) { errno = EEXIST; return -1; }
    if ((flags & XATTR_REPLACE) && !exists) { errno = ENODATA; return -1; }
    if (size > 16384) { errno = E2BIG; return -1; }
    int out = openat(fd, RECORD, O_WRONLY | O_CREAT | O_TRUNC | O_NOFOLLOW | O_CLOEXEC, 0600);
    if (out < 0) return -1;
    size_t done = 0;
    while (done < size) {
        ssize_t n = write(out, (const char *)value + done, size - done);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) { int error = errno; close(out); errno = error; return -1; }
        done += n;
    }
    return close(out);
}

ssize_t fgetxattr(int fd, const char *name, void *value, size_t size)
{
    static ssize_t (*original)(int, const char *, void *, size_t);
    if (!original) original = dlsym(RTLD_NEXT, "fgetxattr");
    if (!eligible(fd, name)) return original(fd, name, value, size);
    int in = openat(fd, RECORD, O_RDONLY | O_NOFOLLOW | O_CLOEXEC);
    if (in < 0) { if (errno == ENOENT) errno = ENODATA; return -1; }
    struct stat st;
    if (fstat(in, &st) || !S_ISREG(st.st_mode)) { close(in); errno = EIO; return -1; }
    if (!size) { close(in); return st.st_size; }
    if (size < (size_t)st.st_size) { close(in); errno = ERANGE; return -1; }
    size_t done = 0;
    while (done < (size_t)st.st_size) {
        ssize_t n = read(in, (char *)value + done, st.st_size - done);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) { close(in); errno = EIO; return -1; }
        done += n;
    }
    close(in);
    return done;
}

ssize_t getxattr(const char *path, const char *name, void *value, size_t size)
{
    static ssize_t (*original)(const char *, const char *, void *, size_t);
    if (!original) original = dlsym(RTLD_NEXT, "getxattr");
    if (strcmp(name, "user.WINEREPARSE")) return original(path, name, value, size);
    int fd = open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC);
    if (fd < 0) return original(path, name, value, size);
    ssize_t result = fgetxattr(fd, name, value, size);
    int error = errno;
    close(fd);
    errno = error;
    return result;
}

int fremovexattr(int fd, const char *name)
{
    static int (*original)(int, const char *);
    if (!original) original = dlsym(RTLD_NEXT, "fremovexattr");
    if (!eligible(fd, name)) return original(fd, name);
    int result = unlinkat(fd, RECORD, 0);
    if (result && errno == ENOENT) errno = ENODATA;
    return result;
}
