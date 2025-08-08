find_program(BPFOBJECT_CLANG_EXE NAMES clang DOC "Path to clang executable")

execute_process(COMMAND ${BPFOBJECT_CLANG_EXE} --version
  OUTPUT_VARIABLE CLANG_version_output
  ERROR_VARIABLE CLANG_version_error
  RESULT_VARIABLE CLANG_version_result
  OUTPUT_STRIP_TRAILING_WHITESPACE)

# Check that clang is new enough
if(${CLANG_version_result} EQUAL 0)
  if("${CLANG_version_output}" MATCHES "clang version ([^\n]+)\n")
    # Transform X.Y.Z into X;Y;Z which can then be interpreted as a list
    set(CLANG_VERSION "${CMAKE_MATCH_1}")
    string(REPLACE "." ";" CLANG_VERSION_LIST ${CLANG_VERSION})
    list(GET CLANG_VERSION_LIST 0 CLANG_VERSION_MAJOR)

    # Anything older than clang 10 doesn't really work
    string(COMPARE LESS ${CLANG_VERSION_MAJOR} 10 CLANG_VERSION_MAJOR_LT10)
    if(${CLANG_VERSION_MAJOR_LT10})
      message(FATAL_ERROR "clang ${CLANG_VERSION} is too old for BPF CO-RE")
    endif()

    message(STATUS "Found clang version: ${CLANG_VERSION}")
  else()
    message(FATAL_ERROR "Failed to parse clang version string: ${CLANG_version_output}")
  endif()
else()
  message(FATAL_ERROR "Command \"${BPFOBJECT_CLANG_EXE} --version\" failed with output:\n${CLANG_version_error}")
endif()

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(BpfObject
  REQUIRED_VARS
    BPFOBJECT_BPFTOOL_EXE
    BPFOBJECT_CLANG_EXE
    LIBBPF_INCLUDE_DIRS
    LIBBPF_LIBRARIES
    BPFOBJECT_VMLINUX_H
    GENERATED_VMLINUX_DIR)

execute_process(
  COMMAND bash -c "${BPFOBJECT_CLANG_EXE} -v -E - < /dev/null 2>&1 |
          sed -n '/<...> search starts here:/,/End of search list./{ s| \\(/.*\\)|-idirafter \\1|p }'"
  OUTPUT_VARIABLE CLANG_SYSTEM_INCLUDES_output
  ERROR_VARIABLE CLANG_SYSTEM_INCLUDES_error
  RESULT_VARIABLE CLANG_SYSTEM_INCLUDES_result
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(${CLANG_SYSTEM_INCLUDES_result} EQUAL 0)
  separate_arguments(CLANG_SYSTEM_INCLUDES UNIX_COMMAND ${CLANG_SYSTEM_INCLUDES_output})
  message(STATUS "BPF system include flags: ${CLANG_SYSTEM_INCLUDES}")
else()
  message(FATAL_ERROR "Failed to determine BPF system includes: ${CLANG_SYSTEM_INCLUDES_error}")
endif()

execute_process(COMMAND uname -m
  COMMAND sed -e "s/x86_64/x86/" -e "s/aarch64/arm64/" -e "s/ppc64le/powerpc/" -e "s/mips.*/mips/" -e "s/riscv64/riscv/"
  OUTPUT_VARIABLE ARCH_output
  ERROR_VARIABLE ARCH_error
  RESULT_VARIABLE ARCH_result
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(${ARCH_result} EQUAL 0)
  set(ARCH ${ARCH_output})
  message(STATUS "BPF target arch: ${ARCH}")
else()
  message(FATAL_ERROR "Failed to determine target architecture: ${ARCH_error}")
endif()

macro(bpf_object name input)
  set(BPF_C_FILE ${input})
  foreach(arg ${ARGN})
    list(APPEND BPF_H_FILES ${CMAKE_CURRENT_SOURCE_DIR}/${arg})
  endforeach()
  set(BPF_O_FILE ${BPF_KERN_OBJECT_DIR}/${name}.bpf.o)
  set(BPF_SKEL_FILE ${CMAKE_CURRENT_BINARY_DIR}/skel_include/${name}.skel.h)
  set(OUTPUT_TARGET ${name}_skelton)

  # Build BPF object file
  add_custom_command(OUTPUT ${BPF_O_FILE}
    COMMAND ${BPFOBJECT_CLANG_EXE} -g -O2 -target bpf -D__TARGET_ARCH_${ARCH}
            ${CLANG_SYSTEM_INCLUDES} -I${GENERATED_VMLINUX_DIR}
            -isystem ${LIBBPF_INCLUDE_DIRS} -c ${BPF_C_FILE} -o ${BPF_O_FILE}
    COMMAND_EXPAND_LISTS
    VERBATIM
    DEPENDS ${BPF_C_FILE} ${BPF_H_FILES}
    COMMENT "[clang] Building BPF object: ${name}")

  # Build BPF skeleton header
  add_custom_command(OUTPUT ${BPF_SKEL_FILE}
    COMMAND bash -c "${BPFOBJECT_BPFTOOL_EXE} gen skeleton ${BPF_O_FILE} > ${BPF_SKEL_FILE}"
    VERBATIM
    DEPENDS ${BPF_O_FILE}
    COMMENT "[skel]  Building BPF skeleton: ${name}")

  add_library(${OUTPUT_TARGET} INTERFACE)
  target_sources(${OUTPUT_TARGET} INTERFACE ${BPF_SKEL_FILE})
  target_include_directories(${OUTPUT_TARGET} INTERFACE ${CMAKE_CURRENT_BINARY_DIR})
  target_include_directories(${OUTPUT_TARGET} SYSTEM INTERFACE ${LIBBPF_INCLUDE_DIRS})
  target_link_libraries(${OUTPUT_TARGET} INTERFACE ${LIBBPF_LIBRARIES} -lelf -lz)
endmacro()
