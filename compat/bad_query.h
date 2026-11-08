#pragma once

#include <stdbool.h>
#include <stdint.h>

// Legacy ABI used by Filza and embedded 3105; implemented using worse_query.
int64_t bad_query(char *path, bool create, char *group_identifier, bool is_group);
char *bad_query_list(char *path, int64_t max_inode); // malloc-owned; caller frees
void bad_query_release(int64_t handle);

// Mond 2.2 has a fifth, diagnostic-only probe_leaf argument.
int64_t mond_bad_query(char *path, bool create, char *group_identifier,
                       bool is_group, char *probe_leaf);
char *mond_bad_query_list(char *path, int64_t max_inode);
void mond_bad_query_release(int64_t handle);
