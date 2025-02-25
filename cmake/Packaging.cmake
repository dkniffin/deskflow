# SPDX-FileCopyrightText: (C) 2024 Chris Rizzitello <sithlord48@gmail.com>
# SPDX-FileCopyrightText: (C) 2012 - 2024 Symless Ltd.
# SPDX-FileCopyrightText: (C) 2009 - 2012 Nick Bolton
# SPDX-License-Identifier: MIT


#
# If enabled, configure packaging based on OS.
#
macro(configure_packaging)

  set(DESKFLOW_PROJECT_RES_DIR ${PROJECT_SOURCE_DIR}/res)
  configure_file(${CMAKE_SOURCE_DIR}/cmake/CPackOptions.cmake.in
                 ${CMAKE_BINARY_DIR}/cmake/CPackOptions.cmake @ONLY)
  set(CPACK_PROJECT_CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/CPackOptions.cmake)

  if(${BUILD_INSTALLER})
    set(CPACK_PACKAGE_NAME ${DESKFLOW_APP_ID})
    set(CPACK_PACKAGE_CONTACT ${DESKFLOW_MAINTAINER})
    set(CPACK_PACKAGE_DESCRIPTION ${CMAKE_PROJECT_DESCRIPTION})
    set(CPACK_PACKAGE_VENDOR ${DESKFLOW_AUTHOR_NAME})
    set(CPACK_RESOURCE_FILE_LICENSE ${PROJECT_SOURCE_DIR}/LICENSE)

    if(NOT CPACK_PACKAGE_VERSION)
      set(CPACK_PACKAGE_VERSION ${DESKFLOW_VERSION})
    endif()

    if(${CMAKE_SYSTEM_NAME} MATCHES "Windows")
      configure_windows_packaging()
    elseif(${CMAKE_SYSTEM_NAME} MATCHES "Darwin")
      configure_mac_packaging()
    elseif(${CMAKE_SYSTEM_NAME} MATCHES "Linux")
      configure_linux_packaging()
    elseif(${CMAKE_SYSTEM_NAME} MATCHES "|.*BSD")
      message(STATUS "BSD packaging not yet supported")
      set(OS_STRING ${CMAKE_SYSTEM_NAME}_${CMAKE_SYSTEM_PROCESSOR})
    endif()

    # cmake-format: off
   set(CPACK_PACKAGE_FILE_NAME "${CPACK_PACKAGE_NAME}-${CPACK_PACKAGE_VERSION}-${OS_STRING}")
   # cmake-format: on

    include(CPack)
  else()
    message(STATUS "Not configuring installer")
  endif()

endmacro()

#
# Windows installer
#
macro(configure_windows_packaging)

  message(VERBOSE "Configuring Windows installer")

  set(QT_PATH $ENV{CMAKE_PREFIX_PATH})

  set(DESKFLOW_MSI_64_GUID
      "027D1C8A-E7A5-4754-BB93-B2D45BFDBDC8"
      CACHE STRING "GUID for 64-bit MSI installer")

  set(DESKFLOW_MSI_32_GUID
      "8F57C657-BC87-45E6-840E-41242A93511C"
      CACHE STRING "GUID for 32-bit MSI installer")

  configure_files(${PROJECT_SOURCE_DIR}/res/dist/wix
                  ${PROJECT_BINARY_DIR}/installer)

  if(CMAKE_SIZEOF_VOID_P EQUAL 8)
    set(OS_STRING "win64")
  elseif(CMAKE_SIZEOF_VOID_P EQUAL 4)
    set(OS_STRING "win32")
  endif()

endmacro()

#
# macOS app bundle
#
macro(configure_mac_packaging)

  message(VERBOSE "Configuring macOS app bundle")

  set(CMAKE_INSTALL_RPATH
      "@loader_path/../Libraries;@loader_path/../Frameworks")
  set(DESKFLOW_BUNDLE_SOURCE_DIR
      ${PROJECT_SOURCE_DIR}/res/dist/mac/bundle
      CACHE PATH "Path to the macOS app bundle")
  set(DESKFLOW_BUNDLE_DIR ${PROJECT_BINARY_DIR}/bundle/${DESKFLOW_APP_NAME}.app)
  set(DESKFLOW_BUNDLE_BINARY_DIR ${DESKFLOW_BUNDLE_DIR}/Contents/MacOS)

  configure_files(${DESKFLOW_BUNDLE_SOURCE_DIR} ${DESKFLOW_BUNDLE_DIR})
  set(OS_STRING "macos")

  file(RENAME ${DESKFLOW_BUNDLE_DIR}/Contents/Resources/App.icns
       ${DESKFLOW_BUNDLE_DIR}/Contents/Resources/${DESKFLOW_APP_NAME}.icns)

endmacro()

#
# Linux packages
#

macro(configure_linux_package_name)
  # Get Distro name information
  execute_process(
    COMMAND bash "-c" "cat /etc/os-release | grep ^ID= | sed 's/ID=//g'"
    OUTPUT_VARIABLE _DISTRO_NAME
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE "\"" "" DISTRO_NAME "${_DISTRO_NAME}")
  message(STATUS "DISTRO NAME: ${DISTRO_NAME}")

  execute_process(
    COMMAND bash "-c"
            "cat /etc/os-release | grep ^ID_LIKE= | sed 's/ID_LIKE=//g'"
    OUTPUT_VARIABLE _DISTRO_LIKE
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE "\"" "" DISTRO_LIKE "${_DISTRO_LIKE}")
  message(STATUS "DISTRO LIKE: ${DISTRO_LIKE}")

  execute_process(
    COMMAND
      bash "-c"
      "cat /etc/os-release | grep ^VERSION_CODENAME= | sed 's/VERSION_CODENAME=//g'"
    OUTPUT_VARIABLE _DISTRO_CODENAME
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE "\"" "" DISTRO_CODENAME "${_DISTRO_CODENAME}")
  message(STATUS "DISTRO CODENAME: ${DISTRO_CODENAME}")

  execute_process(
    COMMAND bash "-c"
            "cat /etc/os-release | grep ^VERSION_ID= | sed 's/VERSION_ID=//g'"
    OUTPUT_VARIABLE _DISTRO_VERSION_ID
    OUTPUT_STRIP_TRAILING_WHITESPACE)
  string(REPLACE "\"" "" DISTRO_VERSION_ID "${_DISTRO_VERSION_ID}")
  message(STATUS "DISTRO ID: ${DISTRO_VERSION_ID}")

  # Set Run Attempt portion of package name
  # GITHUB_RUN_ATTEMPT is set by GITHUB when a job is run
  # It is equal to the number of times the job was run on the same hash
  set(PACKAGE_BUILD_ATTEMPT $ENV{GITHUB_RUN_ATTEMPT})
  if("$ENV{GITHUB_RUN_ATTEMPT}" STREQUAL "")
    set(PACKAGE_BUILD_ATTEMPT 1)
  endif()

  # Check if Debian-like
  string(REGEX MATCH debian|buntu DEBTYPE "${DISTRO_LIKE}")
  if((NOT ("${DEBTYPE}" STREQUAL "")) OR ("${DISTRO_NAME}" STREQUAL "debian"))
    if("${CPACK_DEBIAN_PACKAGE_RELEASE}" STREQUAL "")
      set(CPACK_DEBIAN_PACKAGE_RELEASE
          "${PACKAGE_BUILD_ATTEMPT}~${DISTRO_CODENAME}")
    endif()
    set(CPACK_GENERATOR "DEB")
    message(STATUS "DEB RELEASE INFO: ${CPACK_DEBIAN_PACKAGE_RELEASE}")
  endif()

  check_is_rpm()

  if("${DISTRO_NAME}" STREQUAL "arch")
      set(DISTRO_VERSION_ID "")
      # Arch linux is rolling the version id reported is the date of last iso.
  endif()

  # Determain the code name to be used
  if(NOT "${DISTRO_VERSION_ID}" STREQUAL "")
    set(CN_STRING "${DISTRO_VERSION_ID}-")
  endif()

  if(NOT "${DISTRO_CODENAME}" STREQUAL "")
    set(CN_STRING "${DISTRO_CODENAME}-")
  endif()
  set(OS_STRING "${DISTRO_NAME}-${CN_STRING}${CMAKE_SYSTEM_PROCESSOR}")

  message(STATUS "OS INFO: ${OS_STRING}")

endmacro()

macro(configure_linux_packaging)

  message(VERBOSE "Configuring Linux packaging")

  # Gather distro info
  # This is used in package names
  configure_linux_package_name()

  set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
  set(CPACK_DEBIAN_PACKAGE_MAINTAINER ${DESKFLOW_MAINTAINER})
  set(CPACK_DEBIAN_PACKAGE_SECTION "utils")
  set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)

  set(CPACK_RPM_FILE_NAME RPM-DEFAULT)
  set(CPACK_RPM_PACKAGE_LICENSE "GPLv2")
  set(CPACK_RPM_PACKAGE_GROUP "Applications/System")

  # HACK: The GUI depends on the Qt6 QPA plugins package, but that's not picked
  # up by shlibdeps on Ubuntu 22 (though not a problem on Ubuntu 24 and Debian
  # 12), so we must add it manually.
  set(CPACK_DEBIAN_PACKAGE_DEPENDS "qt6-qpa-plugins")

  set(source_desktop_file ${DESKFLOW_PROJECT_RES_DIR}/dist/linux/app.desktop.in)
  set(configured_desktop_file ${PROJECT_BINARY_DIR}/app.desktop)
  set(install_desktop_file ${DESKFLOW_APP_ID}.desktop)

  configure_file(${source_desktop_file} ${configured_desktop_file} @ONLY)

  install(
    FILES ${configured_desktop_file}
    DESTINATION share/applications
    RENAME ${install_desktop_file})

  install(
    FILES ${DESKFLOW_RES_DIR}/app.png
    DESTINATION share/pixmaps
    RENAME ${DESKFLOW_APP_ID}.png)

  # Prepare PKGBUILD for Arch Linux
  configure_file(${DESKFLOW_PROJECT_RES_DIR}/dist/arch/PKGBUILD.in
                 ${CMAKE_BINARY_DIR}/PKGBUILD @ONLY)

endmacro()

#
# Same as the `configure_file` command but for directories recursively.
#
macro(configure_files srcDir destDir)

  message(VERBOSE "Configuring directory ${destDir}")
  make_directory(${destDir})

  file(
    GLOB_RECURSE sourceFiles
    RELATIVE ${srcDir}
    ${srcDir}/*)
  file(
    GLOB_RECURSE templateFiles
    LIST_DIRECTORIES false
    RELATIVE ${srcDir}
    ${srcDir}/*.in)
  list(REMOVE_ITEM sourceFiles ${templateFiles})

  foreach(sourceFile ${sourceFiles})
    set(sourceFilePath ${srcDir}/${sourceFile})
    if(IS_DIRECTORY ${sourceFilePath})
      message(VERBOSE "Copying directory ${sourceFile}")
      make_directory(${destDir}/${sourceFile})
    else()
      message(VERBOSE "Copying file ${sourceFile}")
      configure_file(${sourceFilePath} ${destDir}/${sourceFile} COPYONLY)
    endif()

  endforeach(sourceFile)

  foreach(templateFile ${templateFiles})

    set(sourceTemplateFilePath ${srcDir}/${templateFile})
    string(REGEX REPLACE "\.in$" "" templateFile ${templateFile})
    message(VERBOSE "Configuring file ${templateFile}")
    configure_file(${sourceTemplateFilePath} ${destDir}/${templateFile} @ONLY)

  endforeach(templateFile)

endmacro(configure_files)

macro(check_is_rpm)
  # Check if RPM-like.
  string(REGEX MATCH suse|fedora|rhel RPMTYPE "${DISTRO_LIKE}")
  string(REGEX MATCH fedora|suse|rhel RPMNAME "${DISTRO_NAME}")
  if((NOT ("${RPMTYPE}" STREQUAL "")) OR (NOT ("${RPMNAME}" STREQUAL "")))

    if("${DISTRO_NAME}" STREQUAL "opensuse-tumbleweed")
      set(DISTRO_NAME "opensuse")
      set(DISTRO_CODENAME "tumbleweed")
    elseif(("${DISTRO_NAME}" STREQUAL "almalinux") OR ("${DISTRO_NAME}" STREQUAL "rocky"))
      string(REGEX MATCH [0-9]+ V "${DISTRO_VERSION_ID}")
      set(RPM_CN "${DISTRO_NAME}${V}")
    endif()

    # Determine if we hsould use
    if ("${RPM_CN}" STREQUAL "")
      if(NOT "${DISTRO_VERSION_ID}" STREQUAL "")
        set(RPM_CN "${DISTRO_VERSION_ID}")
      endif()
      if(NOT "${DISTRO_CODENAME}" STREQUAL "")
        set(RPM_CN "${DISTRO_CODENAME}")
      endif()
    endif()

    if("${CPACK_RPM_PACKAGE_RELEASE}" STREQUAL "")
      set(CPACK_RPM_PACKAGE_RELEASE "${PACKAGE_BUILD_ATTEMPT}~${RPM_CN}")
    endif()

    set(CPACK_GENERATOR "RPM")
    message(STATUS "RPM RELEASE INFO: ${CPACK_RPM_PACKAGE_RELEASE}")

  endif()
endmacro()

