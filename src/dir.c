#include <dirent.h>
#include <errno.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>
#include "mycp.h"

/*
 * Phase 1: walk the tree below src. Directories are created in dst at once
 * (and remembered in dirs so their permissions can be set at the end);
 * regular files are put in the files queue. Returns the number of errors.
 * dst_dev/dst_ino identify the top destination directory so that copying a
 * folder into itself does not recurse forever.
 */
static int scan_tree(const char *src, const char *dst, Queue *files, Queue *dirs,
                     dev_t dst_dev, ino_t dst_ino)
{
    DIR           *dir = opendir(src);
    struct dirent *entry;
    int            errors = 0;

    if (!dir) {
        perror(src);
        return 1;
    }

    while ((entry = readdir(dir)) != NULL) {
        char        s[PATH_MAX_LEN], d[PATH_MAX_LEN];
        struct stat est;

        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0)
            continue;

        if (snprintf(s, sizeof s, "%s/%s", src, entry->d_name) >= (int)sizeof s ||
            snprintf(d, sizeof d, "%s/%s", dst, entry->d_name) >= (int)sizeof d) {
            fprintf(stderr, "path too long: %s/%s\n", src, entry->d_name);
            errors++;
            continue;
        }
        if (lstat(s, &est) < 0) {
            perror(s);
            errors++;
            continue;
        }

        if (S_ISDIR(est.st_mode)) {
            if (est.st_dev == dst_dev && est.st_ino == dst_ino) {
                fprintf(stderr, "Skipping %s (it is the destination)\n", s);
                continue;
            }
            if (mkdir(d, (est.st_mode & 0777) | 0700) < 0 && errno != EEXIST) {
                perror(d);
                errors++;
                continue;
            }
            if (queue_push(dirs, s, d, 0, 0, est.st_mode & 07777) < 0) {
                perror("queue_push");
                errors++;
                continue;
            }
            errors += scan_tree(s, d, files, dirs, dst_dev, dst_ino);
        } else if (S_ISREG(est.st_mode)) {
            if (queue_push(files, s, d, est.st_size, est.st_mtime, est.st_mode) < 0) {
                perror("queue_push");
                errors++;
            }
        } else {
            fprintf(stderr, "Skipping %s (not a regular file or directory)\n", s);
        }
    }
    closedir(dir);
    return errors;
}

/* Recursively copy the contents of src into dst. Returns 0 if no errors. */
int copy_directory(const char *src, const char *dst, const Options *opt)
{
    struct stat src_st, dst_st;
    Queue       files, dirs;
    Stats       stats = { 0, 0, 0, 0 };
    Task       *t;
    Task      **order;
    size_t      n, i;

    if (stat(src, &src_st) < 0) {
        perror(src);
        return -1;
    }
    if (mkdir(dst, (src_st.st_mode & 0777) | 0700) < 0 && errno != EEXIST) {
        perror(dst);
        return -1;
    }
    if (stat(dst, &dst_st) < 0 || !S_ISDIR(dst_st.st_mode)) {
        fprintf(stderr, "%s: not a directory\n", dst);
        return -1;
    }

    queue_init(&files);
    queue_init(&dirs);

    /* phase 1: scan */
    stats.failed += (size_t)scan_tree(src, dst, &files, &dirs,
                                      dst_st.st_dev, dst_st.st_ino);

    /* phase 2: copy the queued files one by one */
    while ((t = queue_pop(&files)) != NULL) {
        if (opt->sync && is_up_to_date(t->size, t->mtime, t->dst)) {
            printf("Skipping %s (up to date)\n", t->src);
            stats.skipped++;
        } else {
            printf("Copying %s -> %s\n", t->src, t->dst);
            if (opt->show_info) {
                struct stat fst;
                if (stat(t->src, &fst) == 0)
                    print_file_info(t->src, &fst);
            }
            if (copy_file(t->src, t->dst, opt) == 0) {
                stats.copied++;
                stats.bytes += t->size;
            } else {
                stats.failed++;
            }
        }
        task_free(t);
    }

    /* phase 3: restore directory permissions, deepest directories first */
    n = dirs.count;
    order = n ? malloc(n * sizeof *order) : NULL;
    if (order) {
        for (i = 0; i < n; i++)
            order[i] = queue_pop(&dirs);
        for (i = n; i > 0; i--) {
            if (chmod(order[i - 1]->dst, order[i - 1]->mode) < 0)
                perror(order[i - 1]->dst);
            task_free(order[i - 1]);
        }
        free(order);
    } else {
        queue_clear(&dirs);
    }
    if (chmod(dst, src_st.st_mode & 07777) < 0)
        perror(dst);

    printf("Summary: %zu copied, %zu skipped, %zu failed (%lld bytes)\n",
           stats.copied, stats.skipped, stats.failed, (long long)stats.bytes);
    log_msg("DIR %s -> %s: %zu copied, %zu skipped, %zu failed",
            src, dst, stats.copied, stats.skipped, stats.failed);

    return stats.failed ? -1 : 0;
}
