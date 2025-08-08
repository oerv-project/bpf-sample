#include <errno.h>
#include <unistd.h>
#include <sys/resource.h>
#include <bpf/libbpf.h>

int main(int argc, char **argv)
{
    struct bpf_object *obj;
    struct bpf_program *prog;
    struct bpf_link *link = NULL;
    int err;

    /* 打开并解析 BPF 对象文件 */
    obj = bpf_object__open_file(BPF_KERN_OBJECT, NULL);
    if (libbpf_get_error(obj)) {
        fprintf(stderr, "Failed to open BPF object file\n");
        return 1;
    }

    /* 加载 BPF 程序到内核 */
    err = bpf_object__load(obj);
    if (err) {
        fprintf(stderr, "Failed to load BPF object: %d\n", err);
        goto cleanup;
    }

    /* 查找我们的程序 */
    prog = bpf_object__find_program_by_name(obj, "entry_hello");
    if (!prog) {
        fprintf(stderr, "Failed to find BPF program\n");
        err = -ENOENT;
        goto cleanup;
    }

    /* 附加程序到 sys_entry_write 钩子点 */
    link = bpf_program__attach(prog);
    if (libbpf_get_error(link)) {
        fprintf(stderr, "Failed to attach BPF program\n");
        err = -EINVAL;
        goto cleanup;
    }

    printf("Successfully started! Please run `sudo cat /sys/kernel/debug/tracing/trace` "
           "to see output of the BPF programs.\n");

cleanup:
    bpf_link__destroy(link);
    bpf_object__close(obj);
    return err < 0 ? -err : 0;
}
