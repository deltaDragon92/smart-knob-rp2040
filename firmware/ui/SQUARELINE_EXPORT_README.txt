SquareLine Studio — export in questa cartella (ui/)

• Il file "CMakeLists.txt" che SquareLine può generare qui viene IGNORATO dalla build.
• Il target CMake `ui` è definito solo in ../CMakeLists.txt (radice firmware): raccoglie tutti i *.c in ui/ e imposta include per lv_conf.h e lvgl.

Puoi esportare da SquareLine senza preoccuparti di sovrascrivere CMake: non influisce sulla compilazione Pico.
