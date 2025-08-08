#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

SEC("tracepoint/syscalls/sys_enter_write")
int entry_hello(void* ctx) {
  bpf_printk("Just Hello World!\n");
  return 0;
}

char LICENSE[] SEC("license") = "Dual BSD/GPL";
