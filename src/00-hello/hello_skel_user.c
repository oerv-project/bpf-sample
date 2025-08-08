#include <stdio.h>
#include <unistd.h>
#include <sys/resource.h>
#include <bpf/libbpf.h>
#include "hello.skel.h"

int main(int argc, char **argv)
{
    struct hello_bpf *skel;
    int err;

    /* 打开 BPF 程序 */
    skel = hello_bpf__open();
    if (!skel) {
        fprintf(stderr, "Failed to open BPF skeleton\n");
        return 1;
    }

    /* 加载并验证 BPF 程序 */
    err = hello_bpf__load(skel);
    if (err) {
        fprintf(stderr, "Failed to load and verify BPF skeleton\n");
        goto cleanup;
    }

    /* 附加到 sys_entry_write 钩子点 */
    err = hello_bpf__attach(skel);
    if (err) {
        fprintf(stderr, "Failed to attach BPF program\n");
        goto cleanup;
    }

    printf("Successfully started! Please run `sudo cat /sys/kernel/debug/tracing/trace` "
           "to see output of the BPF programs.\n");

cleanup:
    hello_bpf__destroy(skel);
    return -err;
}
