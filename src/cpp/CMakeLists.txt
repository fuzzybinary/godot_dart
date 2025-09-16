cmake_minimum_required(VERSION 3.21)

set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
project(godot_dart VERSION 0.1)

set(DART_DIR "${PROJECT_SOURCE_DIR}/../dart_dll")
set(GODOT_CPP_DIR "${PROJECT_SOURCE_DIR}/../../godot-cpp")
set(EXAMPLE_DIR "${PROJECT_SOURCE_DIR}/../../example")

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED True)

set(FLOAT_PRECISION "single")
add_subdirectory(${GODOT_CPP_DIR} "godot-cpp")

add_library(godot_dart SHARED
    dart_bindings.cpp
    dart_instance_binding.cpp
    "script/dart_script_instance.cpp"
    gde_c_interface.cpp
    gde_dart_converters.cpp
    gde_wrapper.cpp
    godot_dart.cpp
    godot_dart_runtime_plugin.cpp
    godot_string_wrappers.cpp
    ref_counted_wrapper.cpp
    editor/godot_dart_editor_plugin.cpp
    editor/dart_templates.cpp
    "editor/dart_progress_dialog.cpp"
    script/dart_script_language.cpp
    script/dart_script.cpp
    script/dart_resource_format.cpp
  "dart_binding_c_interface.cpp")

target_include_directories(godot_dart PUBLIC
    "${GODOT_CPP_DIR}/include"
    "${GODOT_CPP_DIR}/gen/include"
    "${GODOT_CPP_DIR}/gdextension"
    "${DART_DIR}/include"
    "${PROJECT_SOURCE_DIR}"
)

set(DART_DLL_NAMES    
    "dart_dll"
)

find_library(DART_DLL_DEBUG
    NAMES ${DART_DLL_NAMES}
    HINTS "${DART_DIR}/bin/debug"
)

find_library(DART_DLL_RELEASE
    NAMES ${DART_DLL_NAMES}
    HINTS "${DART_DIR}/bin/release" 
)

if(WIN32)
    target_compile_definitions(godot_dart PRIVATE
        _HAS_EXCEPTIONS=0
        _SCL_SECURE=0
        _SECURE_SCL=0
        _SCL_SECURE_NO_WARNINGS
        _CRT_SECURE_NO_WARNINGS
        _CRT_SECURE_NO_DEPRECATE        
        _WIN
    )

    target_link_libraries(godot_dart
        dbghelp
        bcrypt
        rpcrt4
        ws2_32
        Iphlpapi
        Psapi
        shlwapi
    )
    set_property(TARGET godot_dart PROPERTY
        MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL"
    )
    set_target_properties(godot_dart PROPERTIES
        VS_DEBUGGER_COMMAND "C:\\Projects\\godot\\bin\\godot.windows.editor.dev.x86_64.exe"
        VS_DEBUGGER_COMMAND_ARGUMENTS "--verbose --editor --path \"C:\\Users\\Jeff Ward\\Projects\\GodotExperiments\\godot_dart\\example\\2d_tutorial\""
    )
elseif(LINUX)
    set(THREADS_PREFER_PTHREAD_FLAG ON)

    find_package(Threads REQUIRED)
    set(RPATH_ARG "-rpath=./")
    if (CMAKE_CXX_COMPILER_ID MATCHES "GNU")
        set(RPATH_ARG "-Wl,-rpath,./")
    elseif (CMAKE_CXX_COMPILER_ID MATCHES "Clang")
        set(RPATH_ARG "-rpath ./")
    endif()
    # Find shared libraries next to the executable
    set_target_properties(godot_dart PROPERTIES
        BUILD_WITH_INSTALL_RPATH FALSE
        LINK_FLAGS ${RPATH_ARG})

    target_link_libraries(godot_dart 
        Threads::Threads
        ${CMAKE_DL_LIBS}
    )
endif()

target_link_libraries(godot_dart godot-cpp)

# TODO: Debug / release dart_dll libraries
target_link_libraries(godot_dart ${DART_DLL_RELEASE})

# Copy dll to sample directories
add_custom_command(TARGET godot_dart POST_BUILD
  COMMAND ${CMAKE_COMMAND} -E copy $<TARGET_FILE:godot_dart> "${EXAMPLE_DIR}/2d_tutorial"
  COMMAND_EXPAND_LISTS
)
