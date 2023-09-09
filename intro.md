wasm 教程：https://www.cntofu.com/book/150/zh/ch1-quick-guide/ch1-01-install.md
1. emcc的安装
安装并激活Emscripten
对MacOS或Linux用户，在控制台切换至emsdk所在目录，执行以下命令：

./emsdk update
./emsdk install latest
emsdk将联网下载并安装Emscripten最新版的各个组件。安装完毕后，执行以下命令配置并激活已安装的Emscripten：

./emsdk activate latest
在新建的控制台中，切换至emsdk所在的目录，执行以下命令：

source ./emsdk_env.sh
将为当前控制台配置Emscripten各个组件的PATH等环境变量。

1. 实例化：`WebAssembly.instantiateStreaming(response, importObj)`，异步实例化，参数是 fetch 的 response，必须要研究如何流式处理
2. importObj: 将结果输出到 JavaScript 层，转换函数

```javascript
// 只使用 cstdio 库的 printf 的情况
var asmLibraryArg = {
  "emscripten_memcpy_big": _emscripten_memcpy_big,
  "fd_write": _fd_write, // print 的 JavaScript 转换函数
};
// 使用 iostream 库的 cout 的情况
var asmLibraryArg = {
  "abort": _abort,
  "emscripten_memcpy_big": _emscripten_memcpy_big,
  "emscripten_resize_heap": _emscripten_resize_heap,
  "environ_get": _environ_get,
  "environ_sizes_get": _environ_sizes_get,
  "fd_close": _fd_close,
  "fd_read": _fd_read,
  "fd_seek": _fd_seek,
  "fd_write": _fd_write,
  "strftime_l": _strftime_l
};
var info = {
  env: asmLibraryArg,
  wasi_snapshot_preview1: asmLibraryArg,
};
WebAssembly.instantiateStreaming(response, info);
```
3. wasm中函数参数类型只能是整型，不支持字符串、数组、结构体，main()中 argv 参数如何传递呢？答：传递指针
4. 通过 asm 对象提供的 stackAlloc，开辟内存空间
5. 使用allocateUTF8OnStack 中 stringToUTF8Array方法，写入字符串到内存中
5. c++中内存地址 4 个字节占用，指针 4 个字节占用
6. int main(int argc, char *argv[])的 argv 每个元素都是指针地址，各 4 字节，是两个字符串的起始地址，还有第三个参数\0
7. 将给定的 Javascript 字符串对象 "str "复制到地址为 "outIdx "的给定字节数组中，并以 UTF8 形式编码，以空字符结束。复制最多需要在 HEAP 中**占用 str.length*4+1 字节的空间**。 使用函数 lengthBytesUTF8 计算该函数将写入的确切字节数（不包括空结束符）。
8. 字符串占用 str.length*4+1 字节的空间


# 编译参数
1. --no-entry：没有 main 入口函数
2. EXPORTED_RUNTIME_METHODS=['ccall', 'cwrap']

# 调用 C++导出函数
1. Module 对象调用 wasm 暴露的接口，有个问题，只能传数字
```javascript
Module = {}
Module.onRuntimeInitialized = () => {
    Module.add(1+2) // 这里真正能拿到暴露的方法
} // 
```
想传别的怎么办？
1. 使用 Module._malloc()在堆内存中分配内存，获取内存地址
2. 将字符串、数组等数据拷贝到分配的内存处
3. 将分配的内存地址传递给 c++暴露的函数处理；
4. 使用 Module._free() 释放内存；

2. 用 ccall 方法调用暴露的接口
3. 用 cwrap 对暴露的接口重新定义（默认不生成 cwrap，需要 EXPORTED_RUNTIME_METHODS 编译参数




# 进程
![391a216464bdc813cbd6a623db8d9461.png](https://ice.frostsky.com/2023/08/16/391a216464bdc813cbd6a623db8d9461.png)
1. 操作系统中的内存管理是非常复杂的，涉及到分页管理，内存寻址等诸多内容。以Intel的 x86 CPU 为例，程序在寻址过程中使用的地址是由段和段内偏移构成的。因此程序中的地址并不能直接用来访问物理内存，这种地址被称为虚拟地址。为了能寻址物理内存，就需要一种变换机制，将虚拟地址映射到物理内存中，这种地址变换机制就是内存管理的一项主要内容。虚拟地址通过段管理机制首先变成中间地址，称为线性地址， 然后再使用分页管理机制将此线性地址映射到物理地址。由此可见操作系统的内存管理有多复杂了。
2. 对于32位计算机系统而言，一个进程的地址空间有4G大小，从 0 到 232。堆空间由低地址向高地址增长；与之相反，栈空间则是由高地址向低地址增长，两者之间大约有3G的虚拟地址空间（最高的1G由内核使用），因此同时分配堆空间和栈空间是比较安全的

3. 堆空间 的分配需要调用专门的函数，如malloc()、alloc()等；同理，堆空间的释放也要调用专门的函数free()。

4. 栈空间与堆空间不同，它不需要使用专门的函数进行分配，也不需要使用专门的函数来释放。栈空间 是在什么时候分配的呢？实际上，每进入一个函数或进入一个代码块时，系统就会自动分配一块栈空间；而当从函数退出或从代码块退出后，就会自动回收之前分配的栈空间。

5. 栈空间与堆空间还有以下两点不同：
    - 栈空间的大小是固定的。对于WebAssembly来说，栈空间的大小设置为5M；而堆空间是动态的，用户可以根据自己的需要分配堆空间。
    - 栈空间的地址是连续的，而堆空间由于是由链表构成的，所以它的地址并不连续。因此，栈空间的分配速度要比堆空间快。


# Memory 对象：
1. WebAssebmly实例的初始内存大小为256页内存，每页内存为64K，即初始内存为 256*64K=16MB。
2. Memory对象管理的内存可以 JavaScript 和 WASM 共同持有，以作通信用
3. JavaScript 中创建和获取：首先创建了一个Memory对象，然后从Memory对象中获取buffer，buffer指向的就是Memory对象管理实际内存
![a](https://ice.frostsky.com/2023/08/18/69809a6193e0479dca513be4823d5227.png)
3.  WASM 中创建和获取
![a](https://ice.frostsky.com/2023/08/18/f14b3d665d3c3dc5a8d8b3ec582be01a.png)
![a](https://ice.frostsky.com/2023/08/18/d904306b2d10152931598422076e3bfb.png)
![a](https://ice.frostsky.com/2023/08/18/9f4c6da5c8f51e5b9e88ab85ffd99de2.png)
4. 代码中的 HEAP8、HEAP16等是对同一块内存的不同表述。对于HEAP8而言，HEAP8[0]表示内存中的第一个字节，HEAP8[1]表示内存中的第二个字节，依次类推；HEAP16[0]表示内存中的前两个字节，HEAP16[1]表示内存中的3、4字节.......这样应用层就可以很容易的使用胶水文件提供的HEAP数组来访问Memory内存了。下图就是HEAP系列数组与Memory内存之间的转换关系。 
5. 除了上面的HEAP数组外，WebAssembly还为我们提供了几个分配/释放内存的API。比如JavaScript层如果想获得WebAssembly的栈空间，可以使用stackAlloc()函数；如果想获得堆空间可以使用malloc()函数，释放堆空间则使用free()。当然，WebAssembly中的malloc()与free()函数都是定制的，而且堆空间与栈空间都是从Memory对象管理的内存中分配的，这一点我们一定要清楚。

```javascript
// 获取 WebAssembly 模块中的内存缓冲区
const wasmMemory = wasmModule.exports.memory;

// 获取 JavaScript 中的 ArrayBuffer 对象
const buffer = new ArrayBuffer(1024);

// 将 JavaScript 中的 ArrayBuffer 对象与 WebAssembly 模块中的内存缓冲区关联起来
wasmModule.exports.updateGlobalBufferAndViews(buffer);

// 在 JavaScript 中使用 ArrayBuffer 对象
const intArray = new Int32Array(buffer);
intArray[0] = 42;
console.log(intArray[0]); // 输出 42

```