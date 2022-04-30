# 簡易編譯器實作
## 程式流程
``` mermaid
graph LR;
input.c -->compiler_hw3.l/compiler_hw3.y;
compiler_hw3.l/compiler_hw3.y-->input.j;
input.j-->Jasmin;
Jasmin-->executable;
executable-->JVM;
```
``` mermaid
graph LR;
src --Lexical Analyzer-->tokens;
tokens--Syntax Analyzer-->id1[syntax tree];
id1[syntax tree]--Code Generator-->id2[generated code];
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
* μC Code (input)
```cpp=1
int x = 3;
int y = 2;
print(x + y);
```
* Jasmin Code 
```java=1
ldc 3
istore 0
ldc 2
istore 1
iload 0
iload 1
iadd
getstatic java/lang/System/out Ljava/io/PrintStream;
swap
invokevirtual java/io/PrintStream/print(I)V 
```
* 生成的```hw3.j```檔
```java=1
.source hw3.j
.class public Main
.super java/lang/Object
.method public static main([Ljava/lang/String;)V
.limit stack 100 ; Define your storage size.
.limit locals 100 ; Define your local space number.
                            

// Jasmin Code ...
ldc 3
istore 0
ldc 2
istore 1
iload 0
iload 1
iadd
getstatic java/lang/System/out Ljava/io/PrintStream;
swap
invokevirtual java/io/PrintStream/print(I)V 
                          

return
.end method
```
## 輸出結果(簡易例子)
```5```