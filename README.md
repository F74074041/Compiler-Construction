# 簡易編譯器實作
## 程式流程
``` mermaid
graph LR;
input.c-->compiler_hw3.l/compiler_hw3.y;
compiler_hw3.l/compiler_hw3.y-->input.j;
input.j-->Jasmin;
Jasmin-->executable;
executable-->JVM;
```


## 執行方法
```
make
./mycompiler input.c 
java -jar jasmin.jar hw3.j
java Main.class
```
執行```mycompiler```後會生成```.j```檔，之後再用```jasmin.jar```跑```.j```檔生成```.class```檔就可以直接執行並輸出結果了。
## 簡易例子
