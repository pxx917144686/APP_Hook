/***
load.s文件，用于导出Jinx入口点符号

有问题～ 联系pxx917144686
*/

.section __DATA,__mod_init_func,mod_init_funcs
.mod_init_func
.align 4
.quad _jinx_entry
.globl _jinx_entry