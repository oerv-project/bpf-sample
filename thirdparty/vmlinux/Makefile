# Makefile for generating BPF BTF header from vmlinux

# Tool paths
BPFTOOL ?= bpftool
OUTPUT_DIR ?= .
DESTKERN ?= /sys/kernel/btf/vmlinux

.PHONY: all clean

all: $(OUTPUT_DIR)

$(OUTPUT_DIR):
	mkdir $@
	$(BPFTOOL) btf dump file $(DESTKERN) format c > $@/vmlinux.h

clean:
	rm -f $(OUTPUT)

install: $(OUTPUT)
	install -m 644 $(OUTPUT) $(DESTDIR)/usr/include/

uninstall:
	rm -f $(DESTDIR)/usr/include/$(OUTPUT)

help:
	@echo "Makefile targets:"
	@echo "  all       - Generate the BTF header (default target)"
	@echo "  clean     - Remove generated files"
	@echo "  install   - Install the header to system include directory"
	@echo "  uninstall - Remove the installed header"
	@echo "  help      - Show this help message"
	@echo ""
	@echo "Variables:"
	@echo "  BPFTOOL   - Path to bpftool (default: bpftool)"
	@echo "  OUTPUT    - Output file name (default: vmlinux-btf.h)"
	@echo "  DESTKERN  - Path to kernel BTF file (default: /sys/kernel/btf/vmlinux)"
