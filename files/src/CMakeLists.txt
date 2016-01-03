cmake_minimum_required(VERSION 2.8)
project(Test)

# 出力各種ディレクトリ指定等
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ../bin)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY lib)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY lib)
set(CMAKE_BUILD_TYPE Debug)

# 外部ライブラリ
include_directories(
	${PROJECT_SOURCE_DIR}/wxwidgets/include
	${PROJECT_SOURCE_DIR}/wxwidgets/lib/vc_x64_lib/mswud)
link_directories(
	${PROJECT_SOURCE_DIR}/wxwidgets/lib/vc_x64_lib)

# 実行ファイルのビルド
add_executable(Test main.cpp)

# 外部ライブラリのリンク
target_link_libraries (Test
	#wxwidget
	wxmsw30ud_core.lib wxbase30ud.lib wxtiffd.lib wxjpegd.lib wxpngd.lib wxzlibd.lib wxregexud.lib
	wxexpatd.lib winmm.lib comctl32.lib rpcrt4.lib wsock32.lib oleacc.lib odbc32.lib)
	#wxmsw30_core.lib wxbase30.lib wxtiff.lib wxjpeg.lib wxpng.lib wxzlib.lib wxregex.lib wxexpat.lib
	#winmm.lib comctl32.lib rpcrt4.lib wsock32.lib oleacc.lib odbc32.lib)



