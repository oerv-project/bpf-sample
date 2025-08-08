cmake_minimum_required(VERSION 3.20.0)
project(bpf-sample LANGUAGES C CXX)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/bin/user)

set(BPF_KERN_OBJECT_DIR "${CMAKE_CURRENT_BINARY_DIR}/bin/kern")
set(BPF_SKEL_INCLUDE_DIR "${CMAKE_CURRENT_BINARY_DIR}/skel_include")
make_directory(${BPF_SKEL_INCLUDE_DIR})
make_directory(${BPF_KERN_OBJECT_DIR})

set(LIBBPF_INCLUDE_DIRS ${CMAKE_CURRENT_BINARY_DIR}/libbpf)
set(LIBBPF_LIBRARIES ${LIBBPF_INCLUDE_DIRS}/libbpf/libbpf.a)

# 在配置阶段编译 libbpf
execute_process(
  COMMAND make BUILD_STATIC_ONLY=1 OBJDIR=${CMAKE_CURRENT_BINARY_DIR}/libbpf/libbpf DESTDIR=${CMAKE_CURRENT_BINARY_DIR}/libbpf INCLUDEDIR= LIBDIR= UAPIDIR= install install_uapi_headers
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/libbpf/src
  RESULT_VARIABLE libbpf_result
)
if(NOT libbpf_result EQUAL 0)
  message(FATAL_ERROR "Failed to build libbpf")
endif()

# 在配置阶段编译 bpftool
set(BPFOBJECT_BPFTOOL_EXE ${CMAKE_CURRENT_BINARY_DIR}/bpftool/bootstrap/bpftool)
make_directory(${CMAKE_CURRENT_BINARY_DIR}/bpftool)
execute_process(
  COMMAND make bootstrap OUTPUT=${CMAKE_CURRENT_BINARY_DIR}/bpftool/
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/bpftool/src
  RESULT_VARIABLE bpftool_result
)
if(NOT bpftool_result EQUAL 0)
  message(FATAL_ERROR "Failed to build bpftool")
endif()

if(${CMAKE_SYSTEM_PROCESSOR} MATCHES "x86_64")
  set(ARCH "x86")
elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "arm")
  set(ARCH "arm")
elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "aarch64")
  set(ARCH "arm64")
elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "ppc64le")
  set(ARCH "powerpc")
elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "mips")
  set(ARCH "mips")
elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "riscv64")
  set(ARCH "riscv")
elseif(${CMAKE_SYSTEM_PROCESSOR} MATCHES "loongarch64")
  set(ARCH "loongarch")
endif()

# 在配置阶段生成 vmlinux.h
set(GENERATED_VMLINUX_DIR ${CMAKE_CURRENT_BINARY_DIR}/vmlinux)
set(BPFOBJECT_VMLINUX_H ${GENERATED_VMLINUX_DIR}/vmlinux.h)
execute_process(
  COMMAND make BPFTOOL=${BPFOBJECT_BPFTOOL_EXE} OUTPUT_DIR=${GENERATED_VMLINUX_DIR}
  WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/thirdparty/vmlinux
  RESULT_VARIABLE vmlinux_result
)
if(NOT vmlinux_result EQUAL 0)
  message(FATAL_ERROR "Failed to generate vmlinux.h")
endif()

find_package(BpfObject REQUIRED)

include_directories(
  ${LIBBPF_INCLUDE_DIRS}
  ${GENERATED_VMLINUX_DIR}
  ${BPF_SKEL_INCLUDE_DIR}
)

file(GLOB_RECURSE apps *_kern.c)
foreach(app ${apps})
  get_filename_component(filename ${app} NAME)
  string(REGEX REPLACE "_kern.c$" "" app_name ${filename})
  get_filename_component(app_dir ${app} DIRECTORY)
  
  bpf_object(${app_name} ${app})
  
  add_executable(${app_name} ${app_dir}/${app_name}_user.c)
  target_link_libraries(${app_name} ${app_name}_skelton)
  target_compile_definitions(${app_name} PRIVATE
    BPF_KERN_OBJECT="${BPF_KERN_OBJECT_DIR}/${app_name}.bpf.o"
  )

  add_executable(${app_name}_skel ${app_dir}/${app_name}_skel_user.c)
  target_link_libraries(${app_name}_skel ${app_name}_skelton)
  target_compile_definitions(${app_name} PRIVATE
    BPF_KERN_OBJECT="${BPF_KERN_OBJECT_DIR}/${app_name}.bpf.o"
  )
endforeach(app apps)
